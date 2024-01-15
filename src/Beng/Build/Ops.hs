module Beng.Build.Ops (
	build,
) where

import Utils.Messaging (debug, debugEq, debugEqS)

import Beng.Build.Context (Context(..), comparePrecedence)
import Beng.Ops.Declarations (Associativity(..))
import Beng.Ops.Definitions (canHavePrefix, mustHavePrefix)
import Beng.Parse.Parsers ((>>>), (@>), (@+>), (>/>), (>/\>), (>^\>), (>\>), Parser, PrefixState(..), State(..), parseAny)
import qualified Beng.Parse.Patterns as Pattern
import Beng.Ops (Op(..), hasSuffix)
import Beng.Ops.Declarations (Declaration(..))
import Beng.Types.Ops.Definitions (Definition(..))

-- private

comparisonEquals = debugEqS "precedence comparison"

checkPrecedences :: Context -> Declaration -> Declaration -> (Maybe Ordering -> Bool) -> Bool
checkPrecedences context prev next checkOther =
		debug (show prev ++ " vs " ++ show next) do
	let comparison = comparePrecedence context prev next
	let noComparison = comparisonEquals comparison Nothing
	let associativityOk =
		not (comparisonEquals comparison $ Just EQ) || debugEq
			"previous associativity" prev.associativity
			next.associativity "next associativity"
	(noComparison || checkOther comparison) && associativityOk

hasLowerPrecedenceWithin :: Context -> Declaration -> Declaration -> Bool
hasLowerPrecedenceWithin context prev next =
	checkPrecedences context prev next \comparison ->
		comparisonEquals comparison (Just LT) ||
		comparisonEquals comparison (Just EQ) &&
			debugEqS "associativity" next.associativity Lefty

hasHigherPrecedenceWithin :: Context -> Declaration -> Declaration -> Bool
hasHigherPrecedenceWithin context prev next =
	checkPrecedences context prev next \comparison ->
		comparisonEquals comparison (Just GT) ||
		comparisonEquals comparison (Just EQ) &&
			debugEqS "associativity" next.associativity Righty

parserForDefinition :: PrefixState -> Definition -> Parser Op
parserForDefinition prefixState definition = show definition @> \state -> do
	let oldMinPrecedence = state.minPrecedence
	let oldMaxPrecedence = state.maxPrecedence
	let parseDefinition :: Parser Op =
		Pattern.parse definition.declaration.pattern >\>
		\match -> Op { definition, match }
	let resetMinSetMax :: State -> Op -> State = \s op ->
		s{ minPrecedence = oldMinPrecedence,
			maxPrecedence = if hasSuffix op then oldMaxPrecedence else Just op.definition.declaration }
	state{ prefixState, minPrecedence = Just definition.declaration } >>> (
		parseDefinition >/\>
		resetMinSetMax >^\>
		buildNonPrefixed >/>
		\s -> s{ maxPrecedence = oldMaxPrecedence })

buildNonPrefixed :: Op -> Parser Op
buildNonPrefixed predecessor = "non-prefixed op for " ++ show predecessor @> \state -> do
	let meetsPredecenceRequirement :: Definition -> Bool = \definition ->
			debug ("Checking precedence of " ++ show definition ++ "...") do
		let hasHigherPrecedenceThan = hasHigherPrecedenceWithin state.context
		let hasLowerPrecedenceThan = hasLowerPrecedenceWithin state.context
		maybe True (definition.declaration `hasLowerPrecedenceThan`) state.maxPrecedence &&
			maybe True (definition.declaration `hasHigherPrecedenceThan`) state.minPrecedence

	let nonPrefixedParser :: Op -> Parser Op = \firstArg ->
		parseAny $
			map (parserForDefinition $ AvoidingFor firstArg) $
			filter meetsPredecenceRequirement $
			filter (not . mustHavePrefix) state.context.definitions
	state >>> nonPrefixedParser predecessor

-- exported

build :: String -> Parser Op
build contextDescription = contextDescription @+>
	"prefixed op" @> \state -> do
		state >>> (
			parseAny $
			map (parserForDefinition Needed) $
			filter canHavePrefix state.context.definitions)