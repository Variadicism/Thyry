module Beng.Build.Ops (
	build,
) where

import Utils.Messaging (debug, debugEq, debugEqS)
import qualified Utils.Populace as P

import Beng.Build.Context (Context(..), comparePrecedence)
import Beng.Build.Cards (Card, declaration)
import Beng.Errors (parseError)
import Beng.Ops.Declarations (Associativity(..), canHavePrefix, mustHavePrefix)
import Beng.Parse.Parsers ((>>>), (@>), (@+>), (>/>), (>/\>), (>^\>), (>\>), Parser, PrefixState(..), State(..), parseAny)
import qualified Beng.Parse.Patterns as Pattern
import Beng.Ops (Op(..), hasSuffix)
import Beng.Ops.Declarations (Declaration(..))

import qualified Data.Map as Map

-- private

comparisonEquals = debugEqS "precedence comparison"

checkPrecedences :: Context -> Card -> Card -> (Maybe Ordering -> Bool) -> Bool
checkPrecedences context prev next checkOther =
		debug (show prev ++ " vs " ++ show next) do
	let comparison = comparePrecedence context prev next
	let noComparison = comparisonEquals comparison Nothing
	let associativityOk =
		not (comparisonEquals comparison $ Just EQ) || debugEq
			"previous associativity" prev.declaration.associativity
			next.declaration.associativity "next associativity"
	(noComparison || checkOther comparison) && associativityOk

hasLowerPrecedenceWithin :: Context -> Card -> Card -> Bool
hasLowerPrecedenceWithin context prev next =
	checkPrecedences context prev next \comparison ->
		comparisonEquals comparison (Just LT) ||
		comparisonEquals comparison (Just EQ) &&
			debugEqS "associativity" next.declaration.associativity Lefty

hasHigherPrecedenceWithin :: Context -> Card -> Card -> Bool
hasHigherPrecedenceWithin context prev next =
	checkPrecedences context prev next \comparison ->
		comparisonEquals comparison (Just GT) ||
		comparisonEquals comparison (Just EQ) &&
			debugEqS "associativity" next.declaration.associativity Righty

parseFor :: PrefixState -> Card -> Parser Op
parseFor prefixState card = show card @> \initialState -> do
	let parsePatternToOp :: Parser Op =
		Pattern.parse card.declaration.pattern >\>
		\match -> Op { card, match, location = initialState.location }
	initialState{
			prefixState,
			parent = Just card,
			maxPrecedence = Nothing } >>> (
		parsePatternToOp >/\> (\s op -> s{
			arguments = Map.empty,
			parent = initialState.parent,
			maxPrecedence = if hasSuffix op
				then initialState.maxPrecedence
				else Just op.card }) >^\>
		buildNonPrefixed >/> \s -> s{
			arguments = initialState.arguments,
			maxPrecedence = initialState.maxPrecedence })

buildNonPrefixed :: Op -> Parser Op
buildNonPrefixed predecessor = "non-prefixed op for " ++ show predecessor @> \state -> do
	let meetsPredecenceRequirement :: Card -> Bool = \card ->
			debug ("Checking precedence of " ++ show card ++ "...") do
		let hasHigherPrecedenceThan = hasHigherPrecedenceWithin state.context
		let hasLowerPrecedenceThan = hasLowerPrecedenceWithin state.context
		maybe True (card `hasLowerPrecedenceThan`) state.maxPrecedence &&
			maybe True (card `hasHigherPrecedenceThan`) state.parent

	let nonPrefixedCards =
		filter meetsPredecenceRequirement $
		filter (not . mustHavePrefix . declaration) state.context.deck
	cardPopulace <- P.assert nonPrefixedCards $ parseError state
		"There were no non-prefixed Cards applicable in the current Context!"
	let nonPrefixedParser :: Op -> Parser Op = \firstArg ->
		parseAny $ P.map (parseFor $ AvoidingFor firstArg) cardPopulace
			
	state >>> nonPrefixedParser predecessor

-- exported

build :: String -> Parser Op
build contextDescription = contextDescription @+>
	-- TODO: account for non-prefixed ops that build preops as their first arguments.
	-- Maybe that can wait for the self-hosted rewrite?
	-- It's an extremely niche edge case that would require a significant refactor of this logic.
	"prefixed op" @> \state -> do
		let prefixedCards = filter (canHavePrefix . declaration) state.context.deck
		cardPopulace <- P.assert prefixedCards $ parseError state
			"There were no prefixed Cards applicable in the current Context!"
		state >>> (parseAny $ P.map (parseFor Needed) cardPopulace)