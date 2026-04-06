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

import Beng.Operators ()
import Beng.Build.Context (push)
import {-# SOURCE #-} qualified Beng.Build.Invocations as Op
import Beng.Build.TypeTest (satisfiesDuring)
import Beng.Errors (parseError)
import Beng.Invocations ()
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern)
import {-# SOURCE #-} Beng.Parse.Matches ()
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>/\>), (>-\>))
import Beng.Parse.Parsers.Code (PrefixState(..), State(..))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (compareAsSuperDefault)
import Beng.Parse.Parsers.PatternComparator ()
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Things (satisfiesThing)
import Beng.Types.Errors (Error(..), Fallible)
import Beng.Types.Locations (Location)
import qualified Beng.Types.Locations as Location
import Beng.Types.Invocations (Invocation(..), SomeInvocation(..))
import qualified Beng.Types.Parse.Matches as Match
import qualified Beng.Types.Parse.Parsers.Code as SpaceState
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Patterns (Argument(..), Comparison(..), ComparatorState(..), Mismatch(..), SomePattern(..))
import Beng.Things (SomeThing, PreOpType(..))
import Beng.Types.Things (SomeThing(..), castThing)

import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap
import Data.Char (toLower)
import Data.List.Extra (dropPrefix)
import Control.Monad (when)
import qualified Data.Set as Set

showArg :: String -> SomeThing -> Location -> String
showArg name argType decLoc = show decLoc ++ ":" ++ msgArg name argType

msgArg :: String -> SomeThing -> String
msgArg name argType = do
	let argTypeName = dropPrefix "a " $ dropPrefix "an " $ map toLower $ msg argType
	let contents = if argTypeName == map toLower name
		then name
		else name ++ ", " ++ msg argType
	wrap "'" contents

parseArg :: Argument -> Code.Parser Match.Argument
parseArg Argument{..} = msgArg name argType @> \state -> do
	let (Just parent) = state.parent
	let typeToSatisfy = case castThing argType of
		Just PreOpType{resolvedType} -> resolvedType
		Nothing -> argType
	let checkSatisfiesArgType :: SomeInvocation -> Fallible () = \(SomeInvocation invocation) -> do
		let (Location.Code opLocation) = invocation.location
		let contextualizeError cause = TypeError {
			attemptedCaller = parent,
			argName = name,
			fileLocation = opLocation,
			cause }
		mapError contextualizeError $ (state.context, invocation.returnType) `satisfiesThing` typeToSatisfy

	let argOf invocation = Match.Argument {
		decLoc, name, argType,
		value = SomeThing invocation }
	let putArg invocation state' = do
		let newArg = Match.Argument { name, decLoc, argType, value = SomeThing invocation }
		state' { arguments = Map.insert name newArg state'.arguments }
	case state.prefixState of
		AvoidingFor invocation -> do
			checkSatisfiesArgType invocation
			Code.takeAs "" (argOf invocation) $ putArg invocation $ state{ prefixState = Unneeded }
		Needed -> Error $ parseError state $
			"An op prefix was needed, but " ++ show parent ++ " had none!"
		Unneeded -> prependToError ("in '" ++ name ++ "' of " ++ msg parent ++ ", ") do
			argContext <- prependToError
					("There was an error attempting to build a context to parse the preop for " ++
						wrap "'" name ++ ": ") $
				parent.contextualize name state.arguments (Location.Code state.location)
			when (not $ null argContext) $ debugM $
				pluralCount (length argContext) "contextual operator" ++ " generated for '" ++
					name ++ "': " ++ show argContext

			state{ Code.context = foldl (flip push) state.context argContext } >>>
				Op.build (wrap "'" name)
					>/\> (\s invocation -> putArg invocation s{ Code.context = state.context })
					>-\> (\invocation -> checkSatisfiesArgType invocation >> return invocation)
					>\> \invocation ->
						Match.Argument {
							decLoc, name, argType,
							value = SomeThing invocation }

compareAsSubArg :: Argument -> PatternComparator.Parser
compareAsSubArg self@Argument{..} = msgArg name argType ++ " comparator" @> \state -> do
	case state.rest.requirement of
		[] -> Error $ LeftoverSub $ P.assume state.rest.candidate
		nextSuper:superLeft -> case asPattern nextSuper :: Maybe Argument of
			Just arg -> if state.checkArgTypes &&
					hasError ((state.test, argType) `satisfiesDuring` arg.argType) then
				Error $ Mismatch (SomePattern self) $ P.Populace nextSuper superLeft
			else
				PatternComparator.accept [nextSuper] state
			Nothing -> Error $ Mismatch (SomePattern self) $ P.Populace nextSuper superLeft

instance TPattern.Pattern Match.Argument Argument where
	parse = parseArg
	compareAsSub = compareAsSubArg
	compareAsSuper self = compareAsSuperDefault (SomePattern self)
	showPatternWith useMsg Argument{name,argType,decLoc} = if useMsg
		then msgArg name argType
		else showArg name argType decLoc
	mustHavePrefix _ = False
	mustHaveSuffix _ = False
	canHavePrefix _ = False
	canHaveSuffix _ = False
	canMatchEmpty _ = False
	startingSpaceStates _ = Set.fromList [SpaceState.Word, SpaceState.Space, SpaceState.Punctuation]
	isOptional _ = False
	getArgsUsing _ arg = OMap.singleton (arg.name, arg)

parse :: Argument -> Code.Parser Match.Argument
parse = parseArg
