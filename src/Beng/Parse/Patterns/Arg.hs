module Beng.Parse.Patterns.Arg (
	showArg,
	msgArg,
	parse,
	compareFrom
) where

import Utils.Fallible hiding (Fallible)
import Utils.Messaging (debugM, msg)
import Utils.Lists (wrap)
import qualified Utils.Populace as P
import Utils.Strings (pluralCount)

import Beng.Build.Cards ()
import Beng.Build.Context (pushCard)
import {-# SOURCE #-} qualified Beng.Build.Ops as Op
import Beng.Build.TypeTest (satisfiesDuring)
import Beng.Errors (parseError)
import Beng.Ops ()
import Beng.Parse.Matches (Match(Argument, decLoc, name, argType, op), Parameter(..))
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>/\>), (>-\>))
import Beng.Parse.Parsers.Code (PrefixState(..), State(..))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator ()
import qualified Beng.Parse.Parsers.PatternComparator as PC
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Things (satisfies)
import Beng.Types.Errors (Error(..), Fallible)
import Beng.Types.Locations (Location)
import qualified Beng.Types.Locations as Location
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Declarations (Declaration(..))
import Beng.Types.Parse.Patterns (Mismatch(..))
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Types.Things (Thing, Thing(OpValue), Thing(PreOpType))

import Control.Monad (when)
import Data.Char (toLower)
import Data.List.Extra (dropPrefix)
import qualified Data.Map as Map

-- exported

showArg :: String -> Thing -> Location -> String
showArg name paramType decLoc = show decLoc ++ ":" ++ msgArg name paramType

msgArg :: String -> Thing -> String
msgArg name paramType = do
	let paramTypeName = dropPrefix "a " $ dropPrefix "an " $ map toLower $ msg paramType
	let contents = if paramTypeName == map toLower name
		then name
		else name ++ ", " ++ msg paramType
	wrap "'" contents

parse :: String -> Thing -> Location -> Code.Parser Match
parse name argType decLoc = msgArg name argType @> \state -> do
	-- Arg Patterns are only applicable within ops, so parent must be present.
	let (Just parent) = state.parent

	{- Parsing the argument builds PreOps into Ops, so the result of the Op build
		must remove the PreOp wrapper for type comparison. -}
	let typeToSatisfy = case argType of
		PreOpType resolvedType -> resolvedType
		rawType -> rawType
	let checkSatisfiesArgType :: Op -> Fallible () = \op -> do
		-- This only happens to the op parsed as the argument, so it must be a code location.
		let (Location.Code opLocation) = op.location
		let contextualizeError cause = TypeError {
			attemptedCaller = parent,
			argName = name,
			fileLocation = opLocation,
			cause }
		-- TODO: allow parsing to continue through a type error for better debugging info
		mapError contextualizeError $ (state.context, op.returnType) `satisfies` typeToSatisfy

	let argOf op = Argument { decLoc, name, argType, op }
	let putArg op state = do
		let newArg = Parameter { name, decLoc, paramType = argType, value = OpValue op }
		state { arguments = Map.insert name newArg state.arguments }
	case state.prefixState of
		AvoidingFor op -> do
			checkSatisfiesArgType op
			Code.takeAs "" (argOf op) $ putArg op $ state{ prefixState = Unneeded }
		Needed -> Error $ parseError state $
			"An op prefix was needed, but " ++ show parent ++ " had none!"
		Unneeded -> prependToError ("in '" ++ name ++ "' of " ++ msg parent ++ ", ") do
			-- TODO: add previous arguments as additional context
			argContext <- prependToError
					("There was an error attempting to build a context to parse the preop for " ++
						wrap "'" name ++ ": ") $
				parent.declaration.contextualize name state.arguments (Location.Code state.location)
			when (not $ null argContext) $ debugM $
				pluralCount (length argContext) "contextual card" ++ " generated for '" ++
				name ++ "': " ++ show argContext

			state{ Code.context = foldl (flip pushCard) state.context argContext } >>>
				Op.build (wrap "'" name)
					{- Discard context added by parsing the argument;
						otherwise, context built in arguments will "bubble up" into everything
						after it in the file, leaking scope everywhere. -}
					>/\> (\s op -> putArg op s{ Code.context = state.context })
					>-\> (\op -> checkSatisfiesArgType op >> return op)
					>\> \op -> Argument { decLoc, name, argType, op }

compareFrom :: String -> Thing -> Location -> PatternComparator.Parser
compareFrom name argType decLoc = msgArg name argType ++ " comparator" @> \state -> do
	let self = Pattern.Argument { name, argType, decLoc }
	case state.rest.super of
		-- Sub must start with the current pattern, so P.assume is safe.
		[] -> Error $ LeftoverSub $ P.assume state.rest.sub
		next@Pattern.Argument{}:_ |
				-- TODO: find a way to send this error in the PatternComparator Mismatch
				not (state.checkArgTypes && hasError ((state.test, argType) `satisfiesDuring` next.argType)) ->
			PC.accept [next] state
		nextSuper:superLeft -> Error $ Mismatch self $ P.Populace nextSuper superLeft