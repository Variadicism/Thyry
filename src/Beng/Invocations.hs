module Beng.Invocations (
	Invocation(..),
	SomeInvocation(..),
	collectParameterMatches,
	effectiveBindings,
	isNullary,
	hasPrefix,
	hasSuffix,
	getArgs,
	toCode
) where

import Prelude

import Utils.Fallible (FallibleI(..))
import Utils.Messaging (Messagable, msg)
import qualified Utils.Populace as P

import Beng.Locations ()
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import {-# SOURCE #-} Beng.Parse.Matches ()
import {-# SOURCE #-} Beng.Things ()
import qualified Beng.Types.Operators as Ops
import Beng.Types.Build.Context (Context)
import Beng.Types.Invocations (
	Invocation(Invocation, operator, context, location, match, returnType),
	SomeInvocation(..))
import Beng.Types.Build.TypeTest (ParameterMatchResults(..))
import Beng.Types.Locations ()
import Beng.Types.Parse.Matches (
	Argument(..),
	SomeMatch(..))
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Things (
	ParameterMatches,
	SomeConcreteThing(..))
import qualified Beng.Types.Things as Thing
import qualified Data.Map as Map
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap
import qualified Data.Set as Set
import Data.Text.Lazy (Text, unpack)
import GHC.Records (HasField, getField)

-- instances

instance Eq op => Eq (Invocation op) where
	invocation1 == invocation2 =
		invocation1.location == invocation2.location &&
		invocation1.operator == invocation2.operator &&
		Match.toCode invocation1.match == Match.toCode invocation2.match

instance Show op => Show (Invocation op) where
	show Invocation{..} = show location ++ ": " ++ unpack (Match.toCode match) ++ " as " ++ show operator

instance Messagable op => Messagable (Invocation op) where
	msg Invocation{match} = unpack $ Match.toCode match

instance Show SomeInvocation where
	show (SomeInvocation invocation) = show invocation

instance Messagable SomeInvocation where
	msg (SomeInvocation invocation) = msg invocation

instance Eq SomeInvocation where
	invocation1 == invocation2 = show invocation1 == show invocation2

instance HasField "returnType" SomeInvocation SomeConcreteThing where
	getField (SomeInvocation Invocation{returnType}) = returnType

resolveParameterMatches :: (ParameterMatches -> ParameterMatches)
resolveParameterMatches rawMatches = Map.foldlWithKey addResolvedBindings Map.empty rawMatches
	where
		addResolvedBindings resolvedMatches parameter _ =
			case expandedBindingsOf parameter of
				[] ->
					resolvedMatches
				firstBinding:restBindings ->
					Map.insert parameter (P.Populace firstBinding restBindings) resolvedMatches

		expandedBindingsOf parameter = expandParameterBindings Set.empty parameter

		expandParameterBindings visited parameter =
			if parameter `Set.member` visited then
				[]
			else case Map.lookup parameter rawMatches of
				Nothing ->
					[]
				Just bindings ->
					concatMap
						(expandBinding $ Set.insert parameter visited)
						bindings.l

		expandBinding visited binding@Thing.Binding{thing = Thing.SomeParameterizedThing thing} = case
				Thing.asParameter thing of
			Just boundParameter ->
				expandParameterBindings visited boundParameter
			Nothing ->
				[binding]

effectiveBindings :: ParameterMatches -> ParameterMatchResults -> ParameterMatches
effectiveBindings outerBindings matches = resolveParameterMatches $ Map.unionsWith (<>) [
		outerBindings,
		matches.candidateMatches,
		matches.requirementMatches ]

collectParameterMatches ::
	Ops.Operator op =>
	Context ->
	op ->
	SomeMatch ->
	ParameterMatches ->
	FallibleI Thing.Mismatch ParameterMatchResults
collectParameterMatches context operator match outerBindings =
	collectParameterMatchesFromArguments
		outerBindings
		context
		(Ops.returnType operator)
		(OMap.toMap $ Match.getArgs match)

collectParameterMatchesFromArguments ::
	ParameterMatches ->
	Context ->
	Thing.SomeParameterizedThing ->
	Map.Map String Argument ->
	FallibleI Thing.Mismatch ParameterMatchResults
collectParameterMatchesFromArguments outerBindings _context _partialRequirement arguments = do
	let
		mergeMatches :: ParameterMatchResults -> ParameterMatchResults -> ParameterMatchResults
		mergeMatches left right = ParameterMatchResults {
			candidateMatches = Map.unionWith (<>) left.candidateMatches right.candidateMatches,
			requirementMatches = Map.unionWith (<>) left.requirementMatches right.requirementMatches }
	let initialMatches = ParameterMatchResults {
			candidateMatches = outerBindings,
			requirementMatches = Map.empty }
	return $ foldl
		(\matches argument -> mergeMatches matches argument.parameterMatches)
		initialMatches
		(Map.elems arguments)

-- exports

isNullary :: SomeInvocation -> Bool
isNullary (SomeInvocation invocation) = not $ Pattern.hasArgs $ Ops.pattern invocation.operator

hasPrefix :: SomeInvocation -> Bool
hasPrefix (SomeInvocation invocation) = Match.hasPrefix invocation.match

hasSuffix :: SomeInvocation -> Bool
hasSuffix (SomeInvocation invocation) = Match.hasSuffix invocation.match

getArgs :: SomeInvocation -> OMap String Argument
getArgs (SomeInvocation invocation) = Match.getArgs invocation.match

toCode :: SomeInvocation -> Text
toCode (SomeInvocation invocation) = Match.toCode invocation.match
