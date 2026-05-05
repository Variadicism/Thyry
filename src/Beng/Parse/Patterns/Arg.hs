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
import qualified Beng.Build.TypeTest as Test
import Beng.Errors (parseError)
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern)
import {-# SOURCE #-} Beng.Parse.Matches ()
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>/\>), (>-\>))
import Beng.Parse.Parsers.Code (PrefixState(..), State(..))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (compareAsRequirementDefault)
import Beng.Parse.Parsers.PatternComparator ()
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Build.TypeTest (ParameterMatchResults(..), TypeTest(..))
import Beng.Types.Errors (Error(..), Fallible)
import Beng.Types.Locations (Location)
import qualified Beng.Types.Locations as Location
import Beng.Types.Invocations (
	SomeInvocation(..),
	Invocation(..))
import qualified Beng.Types.Parse.Matches as Match
import qualified Beng.Types.Parse.Parsers.Code as SpaceState
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Types.Parse.Patterns (
	Argument(..),
	Comparison(..),
	ComparatorState(..),
	Mismatch(..),
	Pattern,
	SomePattern(..))
import Beng.Things (PreOpType(..))
import Beng.Types.Things (
	NamedThing(..),
	SomeParameterizedThing(..),
	SomeThing(..),
	castParameterizedThing)
import qualified Beng.Types.Things as Thing

import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap
import Data.Char (toLower)
import Data.List (uncons)
import Data.List.Extra (dropPrefix)
import Control.Monad (when)
import qualified Data.Set as Set

showArg :: String -> SomeParameterizedThing -> Location -> String
showArg name argType decLoc = show decLoc ++ ":" ++ msgArg name argType

msgArg :: String -> SomeParameterizedThing -> String
msgArg name argType = do
	let argTypeName = dropPrefix "a " $ dropPrefix "an " $ map toLower $ msg argType
	let contents = if argTypeName == map toLower name
		then name
		else name ++ ", " ++ msg argType
	wrap "'" contents

parseArg :: Argument -> Code.Parser Match.Argument
parseArg Argument{..} = msgArg name argType @> \state -> do
	let (Just parent) = state.parent
	let emptyParameterMatchResults = ParameterMatchResults {
			candidateMatches = mempty,
			requirementMatches = mempty }
	let
		mergeMatches :: ParameterMatchResults -> ParameterMatchResults -> ParameterMatchResults
		mergeMatches left right = ParameterMatchResults {
			candidateMatches = Map.unionWith (<>) left.candidateMatches right.candidateMatches,
			requirementMatches = Map.unionWith (<>) left.requirementMatches right.requirementMatches }
	let
		trimMatches :: ParameterMatchResults -> ParameterMatchResults -> ParameterMatchResults
		trimMatches oldMatches newMatches = do
			let trimMap oldMap newMap = Map.mapMaybeWithKey
					(\parameter newBindings -> do
						let oldBindings = maybe [] P.toList $ Map.lookup parameter oldMap
						let keptBindings = filter (`notElem` oldBindings) $ P.toList newBindings
						case uncons keptBindings of
							Nothing -> Nothing
							Just (firstBinding, restBindings) ->
								Just $ P.Populace firstBinding restBindings)
					newMap
			ParameterMatchResults {
				candidateMatches = trimMap oldMatches.candidateMatches newMatches.candidateMatches,
				requirementMatches = trimMap
					oldMatches.requirementMatches
					newMatches.requirementMatches }
	let matchesOfArguments = foldl
			(\matches argument -> mergeMatches matches argument.parameterMatches)
			emptyParameterMatchResults
			(Map.elems state.arguments)
	let typeToSatisfy = case castParameterizedThing argType of
		Just PreOpType{resolvedType} -> resolvedType
		Nothing -> argType
	let checkSatisfiesArgType :: SomeInvocation -> Fallible ParameterMatchResults =
			\(SomeInvocation invocation) -> do
		let (Location.Code opLocation) = invocation.location
		let contextualizeError cause = TypeError {
			attemptedCaller = parent,
			argName = name,
			fileLocation = opLocation,
			cause }
		let test = (Test.fromContext
				state.context
				(Thing.parameterize invocation.returnType)
				typeToSatisfy) {
				candidateParameterMatches = matchesOfArguments.candidateMatches,
				requirementParameterMatches = matchesOfArguments.requirementMatches }
		case mapError contextualizeError $ Test.runTest test of
			Error e -> Error e
			Falue newMatches -> Falue $ trimMatches matchesOfArguments newMatches

	let argOf someInvocation parameterMatches = case someInvocation of
		SomeInvocation invocation -> Match.Argument {
			pattern = Argument{decLoc, name, argType},
			matchedType = Thing.parameterize invocation.returnType,
			parameterMatches,
			value = SomeThing someInvocation }
	let putArg someInvocation parameterMatches state' = case someInvocation of
		SomeInvocation invocation -> do
			let newArg = Match.Argument {
				pattern = Argument{decLoc, name, argType},
				matchedType = Thing.parameterize invocation.returnType,
				parameterMatches,
				value = SomeThing someInvocation }
			state' { arguments = Map.insert name newArg state'.arguments }
	case state.prefixState of
		AvoidingFor invocation -> do
			parameterMatches <- checkSatisfiesArgType invocation
			Code.takeAs
				""
				(argOf invocation parameterMatches)
				$ putArg invocation parameterMatches $ state{ prefixState = Unneeded }
		Needed -> Error $ parseError state $
			"An op prefix was needed, but " ++ show parent ++ " had none!"
		Unneeded -> prependToError ("in '" ++ name ++ "' of " ++ msg parent ++ ", ") do
			argContext <- prependToError
					("There was an error attempting to build a context to parse the preop for " ++
						wrap "'" name ++ ": ") $
				do
					parent.contextualize name state.arguments (Location.Code state.location)
			when (not $ null argContext) $ debugM $
				pluralCount (length argContext) "contextual operator" ++ " generated for '" ++
					name ++ "': " ++ show argContext

			let builtArgument = Op.build (wrap "'" name) >-\> \invocation -> do
					parameterMatches <- checkSatisfiesArgType invocation
					return (invocation, parameterMatches)
			let storedArgument = builtArgument
					>/\> (\s (invocation, parameterMatches) ->
						putArg invocation parameterMatches s{ Code.context = state.context })
					>\> uncurry argOf
			state{ Code.context = foldl (flip push) state.context argContext } >>> storedArgument

compareAsCandidateArg :: Argument -> PatternComparator.Parser
compareAsCandidateArg self@Argument{..} = msgArg name argType ++ " comparator" @> \state -> do
	let normalizeArgType typeToNormalize =
			case castParameterizedThing typeToNormalize :: Maybe (NamedThing SomeParameterizedThing) of
				Just _ -> SomeParameterizedThing typeToNormalize
				Nothing -> Thing.parameterize $ Thing.normalize typeToNormalize
	let normalizedArgType = normalizeArgType argType
	case state.rest.requirement of
		[] -> Error $ LeftoverCandidate $ P.assume state.rest.candidate
		nextRequirement:requirementLeft -> case asPattern nextRequirement :: Maybe Argument of
			Just arg -> if state.checkArgTypes then
				case (state.test, normalizedArgType) `satisfiesDuring` arg.argType of
					Error _ -> Error $ Mismatch (SomePattern self) $ P.Populace nextRequirement requirementLeft
					Falue nextTest ->
						PatternComparator.acceptUsing [nextRequirement] nextTest state
			else
				PatternComparator.accept [nextRequirement] state
			Nothing -> Error $ Mismatch (SomePattern self) $ P.Populace nextRequirement requirementLeft

instance Pattern Match.Argument Argument where
	parse = parseArg
	compareAsCandidate = compareAsCandidateArg
	compareAsRequirement self = compareAsRequirementDefault (SomePattern self)
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
