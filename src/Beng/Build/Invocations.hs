module Beng.Build.Invocations (
	build,
) where

import Utils.Messaging (debug, debugEq, debugEqS)
import Utils.Fallible (FallibleI(..))
import qualified Utils.Populace as P
import qualified Data.Map as Map

import Beng.Build.Context (Context(..), comparePrecedence)
import qualified Beng.Operators as Ops
import Beng.Operators (Operator, SomeOperator(..), canHavePrefix, mustHavePrefix)
import Beng.Errors (parseError)
import Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as Match
import Beng.Operators.Declarations (Associativity(..))
import Beng.Parse.Parsers.Code (
	(>>>),
	(@>),
	(@+>),
	(>/>),
	(>/\>),
	(>-\>),
	(>^\>),
	Parser,
	PrefixState(..),
	State(..),
	parseAny )
import qualified Beng.Parse.Patterns as Pattern
import Beng.Invocations (
	Invocation(..),
	collectParameterMatches)
import qualified Beng.Invocations as Inv
import qualified Beng.Types.Locations as Location
import Beng.Types.Invocations (SomeInvocation(..))
import qualified Beng.Types.Parse.Matches as MatchType
import qualified Beng.Types.Things as Thing

-- private

comparisonEquals = debugEqS "precedence comparison"

checkPrecedences :: (Operator prev, Operator next) =>
	Context -> prev -> next -> (Maybe Ordering -> Bool) -> Bool
checkPrecedences context prev next checkOther =
	debug (show prev ++ " vs " ++ show next) do
	let comparison = comparePrecedence context prev next
	let noComparison = comparisonEquals comparison Nothing
	let associativityOk =
		not (comparisonEquals comparison $ Just EQ) || debugEq
			"previous associativity" (Ops.associativity prev)
			(Ops.associativity next) "next associativity"
	(noComparison || checkOther comparison) && associativityOk

hasLowerPrecedenceWithin :: (Operator prev, Operator next) => Context -> prev -> next -> Bool
hasLowerPrecedenceWithin context prev next =
	checkPrecedences context prev next \comparison ->
		comparisonEquals comparison (Just LT) ||
		comparisonEquals comparison (Just EQ) &&
			debugEqS "associativity" (Ops.associativity next) Lefty

hasHigherPrecedenceWithin :: (Operator prev, Operator next) => Context -> prev -> next -> Bool
hasHigherPrecedenceWithin context prev next =
	checkPrecedences context prev next \comparison ->
		comparisonEquals comparison (Just GT) ||
		comparisonEquals comparison (Just EQ) &&
			debugEqS "associativity" (Ops.associativity next) Righty

requiresPrefix :: Operator op => op -> Bool
requiresPrefix = mustHavePrefix

acceptsPrefix :: Operator op => op -> Bool
acceptsPrefix = canHavePrefix

parseFor :: PrefixState -> SomeOperator -> Parser SomeInvocation
parseFor prefixState (SomeOperator op) = parseForTyped prefixState op

parseForTyped :: Operator op => PrefixState -> op -> Parser SomeInvocation
parseForTyped prefixState op = show op @> \initialState ->
	initialState{
			prefixState,
			parent = Just $ SomeOperator op,
			maxPrecedence = Nothing } >>>

		Pattern.parse (Ops.pattern op) >-\>
		(\match -> do
			case collectParameterMatches initialState.context op match Map.empty of
				Falue parameterMatches ->
					let bindings = Inv.effectiveBindings Map.empty parameterMatches
					in case MatchType.resolve bindings match of
						Error resolveError ->
							Error $ parseError initialState $
								"Internal match resolve failure in Beng.Build.Invocations.build: " ++
								show resolveError
						Falue resolvedMatch -> case Thing.resolve bindings (Ops.returnType op) of
							Error resolveError ->
								Error $ parseError initialState $
									"Internal local return resolve failure in Beng.Build.Invocations.build: " ++
									show resolveError
							Falue resolvedReturnType ->
								return $ SomeInvocation Invocation {
									operator = op,
									context = initialState.context,
									match = resolvedMatch,
									location = Location.Code initialState.location,
									returnType = resolvedReturnType }
				Error mismatch ->
					Error $ parseError initialState $
						"Internal local parameter collection failure in " ++ show op ++ ": " ++
						show mismatch) >/\>
		(\s invocation -> s{
			arguments = Map.empty,
			parent = initialState.parent,
			maxPrecedence = case invocation of
				SomeInvocation Invocation{match, operator} -> if Match.hasSuffix match
					then initialState.maxPrecedence
					else Just $ SomeOperator operator }) >^\>

		buildNonPrefixed >/> \s -> s{
			arguments = initialState.arguments,
			maxPrecedence = initialState.maxPrecedence }

buildNonPrefixed :: SomeInvocation -> Parser SomeInvocation
buildNonPrefixed predecessor = "non-prefixed op for " ++ show predecessor @> \state -> do
	let meetsPredecenceRequirement :: SomeOperator -> Bool = \op ->
			debug ("Checking precedence of " ++ show op ++ "...") do
		let hasHigherPrecedenceThan = hasHigherPrecedenceWithin state.context
		let hasLowerPrecedenceThan = hasLowerPrecedenceWithin state.context
		maybe True (op `hasLowerPrecedenceThan`) state.maxPrecedence &&
			maybe True (op `hasHigherPrecedenceThan`) state.parent

	let nonPrefixedOps =
		filter meetsPredecenceRequirement $
		filter (not . requiresPrefix) state.context.ops
	opPopulace <- P.assert nonPrefixedOps $ parseError state
		"There were no non-prefixed operators applicable in the current Context!"
	let nonPrefixedParser :: (SomeInvocation -> Parser SomeInvocation) = \firstArg ->
		parseAny $ P.map (parseFor $ AvoidingFor firstArg) opPopulace
			
	state >>> nonPrefixedParser predecessor

-- exported

build :: String -> Parser SomeInvocation
build contextDescription = contextDescription @+>
	-- TODO: account for non-prefixed ops that build preops as their first arguments.
	-- Maybe that can wait for the self-hosted rewrite?
	-- It's an extremely niche edge case that would require a significant refactor of this logic.
	"prefixed op" @> \state -> do
		let prefixedOps = filter acceptsPrefix state.context.ops
		opPopulace <- P.assert prefixedOps $ parseError state
			"There were no prefixed operators applicable in the current Context!"
		state >>> (parseAny $ P.map (parseFor Needed) opPopulace)
