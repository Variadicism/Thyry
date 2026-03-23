module Beng.Parse.Patterns.Arg (
	showArg,
	msgArg,
	parse
) where

import Utils.Fallible hiding (Fallible)
import Utils.Messaging (Messagable(..), debugM, msg)
import Utils.Lists (wrap)
import qualified Utils.Populace as P
import Utils.Strings (pluralCount)

import Beng.Build.Cards ()
import Beng.Build.Context (pushCard)
import {-# SOURCE #-} qualified Beng.Build.Ops as Op
import Beng.Build.TypeTest (satisfiesDuring)
import Beng.Errors (parseError)
import Beng.Ops ()
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern)
import Beng.Parse.Matches (Match(ArgM))
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>/\>), (>-\>))
import Beng.Parse.Parsers.Code (PrefixState(..), State(..))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator ()
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Things (satisfies)
import Beng.Types.Errors (Error(..), Fallible)
import Beng.Types.Locations (Location)
import qualified Beng.Types.Locations as Location
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Declarations (Declaration(..))
import qualified Beng.Types.Parse.Parsers.Code as SpaceState
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Patterns (ArgP(..), Argument(..), Comparison(..), ComparatorState(..), Mismatch(..), SomePattern(..))
import Beng.Types.Things (Thing, Thing(OpValue), Thing(PreOpType))

import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap
import Data.Char (toLower)
import Data.List.Extra (dropPrefix)
import Control.Monad (when)
import qualified Data.Set as Set

showArg :: String -> Thing -> Location -> String
showArg name argType decLoc = show decLoc ++ ":" ++ msgArg name argType

msgArg :: String -> Thing -> String
msgArg name argType = do
	let argTypeName = dropPrefix "a " $ dropPrefix "an " $ map toLower $ msg argType
	let contents = if argTypeName == map toLower name
		then name
		else name ++ ", " ++ msg argType
	wrap "'" contents

parseArg :: ArgP -> Code.Parser Match
parseArg (ArgP Argument{..}) = msgArg name argType @> \state -> do
	let (Just parent) = state.parent
	let typeToSatisfy = case argType of
		PreOpType resolvedType -> resolvedType
		rawType -> rawType
	let checkSatisfiesArgType :: Op -> Fallible () = \op -> do
		let (Location.Code opLocation) = op.location
		let contextualizeError cause = TypeError {
			attemptedCaller = parent,
			argName = name,
			fileLocation = opLocation,
			cause }
		mapError contextualizeError $ (state.context, op.returnType) `satisfies` typeToSatisfy

	let argOf op = ArgM Match.Argument { decLoc, name, argType, value = OpValue op }
	let putArg op state' = do
		let newArg = Match.Argument { name, decLoc, argType, value = OpValue op }
		state' { arguments = Map.insert name newArg state'.arguments }
	case state.prefixState of
		AvoidingFor op -> do
			checkSatisfiesArgType op
			Code.takeAs "" (argOf op) $ putArg op $ state{ prefixState = Unneeded }
		Needed -> Error $ parseError state $
			"An op prefix was needed, but " ++ show parent ++ " had none!"
		Unneeded -> prependToError ("in '" ++ name ++ "' of " ++ msg parent ++ ", ") do
			argContext <- prependToError
					("There was an error attempting to build a context to parse the preop for " ++
						wrap "'" name ++ ": ") $
				parent.declaration.contextualize name state.arguments (Location.Code state.location)
			when (not $ null argContext) $ debugM $
				pluralCount (length argContext) "contextual card" ++ " generated for '" ++
				name ++ "': " ++ show argContext

			state{ Code.context = foldl (flip pushCard) state.context argContext } >>>
				Op.build (wrap "'" name)
					>/\> (\s op -> putArg op s{ Code.context = state.context })
					>-\> (\op -> checkSatisfiesArgType op >> return op)
					>\> \op -> ArgM Match.Argument { decLoc, name, argType, value = OpValue op }

compareFromArg :: ArgP -> PatternComparator.Parser
compareFromArg self@(ArgP Argument{..}) = msgArg name argType ++ " comparator" @> \state -> do
	case state.rest.super of
		[] -> Error $ LeftoverSub $ P.assume state.rest.sub
		nextSuper:superLeft -> case asPattern nextSuper :: Maybe ArgP of
			Just (ArgP arg) -> if state.checkArgTypes &&
					hasError ((state.test, argType) `satisfiesDuring` arg.argType) then
				Error $ Mismatch (SomePattern self) $ P.Populace nextSuper superLeft
			else
				PatternComparator.accept [nextSuper] state
			Nothing -> Error $ Mismatch (SomePattern self) $ P.Populace nextSuper superLeft

instance Eq ArgP where
	ArgP a1 == ArgP a2 = a1 == a2

instance Show ArgP where
	show (ArgP Argument{name,argType,decLoc}) = showArg name argType decLoc

instance Messagable ArgP where
	msg (ArgP Argument{name,argType}) = msgArg name argType

instance TPattern.Pattern ArgP where
	parse = parseArg
	compareFrom = compareFromArg
	showPatternWith useMsg (ArgP Argument{name,argType,decLoc}) = if useMsg
		then msgArg name argType
		else showArg name argType decLoc
	mustHavePrefix _ = False
	mustHaveSuffix _ = False
	canHavePrefix _ = False
	canHaveSuffix _ = False
	canMatchEmpty _ = False
	startingSpaceStates _ = Set.fromList [SpaceState.Word, SpaceState.Space, SpaceState.Punctuation]
	isOptional _ = False
	getArgsUsing _ (ArgP arg) = OMap.singleton (arg.name, arg)

parse :: ArgP -> Code.Parser Match
parse = parseArg
