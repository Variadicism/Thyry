module Beng.Parse.Patterns.Literal (
	parse
) where

import Utils.Fallible hiding (Fallible)
import Utils.Messaging (Messagable(..))
import qualified Utils.Populace as P
import qualified Utils.Text as UtilsText

import Beng.Errors (parseError)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (>>>))
import Beng.Parse.Parsers.Code (PrefixState(..))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (compareAsRequirementDefault)
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern)
import qualified Beng.Parse.Patterns.CharClass as CC
import qualified Beng.Types.Parse.Patterns as Pattern
import qualified Beng.Types.Parse.Parsers.Code as SpaceState (SpaceState(..))
import Beng.Types.Parse.Patterns (
	CharClass(..),
	Comparison(..),
	ComparatorState(..),
	Literal(..),
	Mismatch(..),
	Pattern,
	SomePattern(..),
	Space(..))

import Data.Char (isAlphaNum, isSpace)
import qualified Data.Set as Set
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

parseLiteral :: Literal -> Code.Parser Match.Literal
parseLiteral (Literal literal) = "literal " ++ show literal @> \state ->
	if not $ literal `Text.isPrefixOf` state.rest then
		Error $ parseError state $ show literal ++ " was expected next!"
	else case state.prefixState of
		AvoidingFor op -> Error $ parseError state $
			"An non-prefixed argument was expected to match " ++ show op ++ ", but a prefix was found!"
		_ -> Code.takeAs literal (Match.Literal literal)
			state{ Code.prefixState = Unneeded }

compareAsCandidateLiteral :: Literal -> PatternComparator.Parser
compareAsCandidateLiteral self@(Literal literal) = show literal ++ " comparator" @> \state ->
	if Text.null literal then
		PatternComparator.accept [] state
	else case state.rest.requirement of
		[] -> Error $ LeftoverCandidate $ P.assume state.rest.candidate
		next:requirementLeft -> do
			let requirementP = P.Populace next requirementLeft
			let swapCandidate newCandidate s = s{ rest = s.rest{ candidate = newCandidate }}
			let swapRequirement newRequirement s = s{ rest = s.rest{ requirement = newRequirement }}
			case asPattern next :: Maybe Literal of
				Just (Literal requirementLiteral) -> if requirementLiteral == literal then
					PatternComparator.accept [next] state
				else if literal `Text.isPrefixOf` requirementLiteral then do
					let remainingRequirement = UtilsText.dropPrefix literal requirementLiteral
					let splitRequirement = [SomePattern self, SomePattern (Literal remainingRequirement)] ++ requirementLeft
					PatternComparator.accept [SomePattern self] $ swapRequirement splitRequirement state
				else if requirementLiteral `Text.isPrefixOf` literal then do
					let remainingCandidate = UtilsText.dropPrefix requirementLiteral literal
					let splitCandidate = next : SomePattern (Literal remainingCandidate) :
						tail state.rest.candidate
					PatternComparator.accept [next] $ swapCandidate splitCandidate state
				else
					compareAgainstNonLiteral self literal next state requirementP swapCandidate
				Nothing -> compareAgainstNonLiteral self literal next state requirementP swapCandidate

compareAsRequirementLiteral :: Literal -> PatternComparator.Parser
compareAsRequirementLiteral self@(Literal literal) = show literal ++ " requirement comparator" @> \state ->
	if Text.null literal then
		case state.rest.requirement of
			_:requirementLeft -> PatternComparator.swapRequirement requirementLeft state >>> PatternComparator.comparator
			[] -> case state.rest.candidate of
				nextCandidate:candidateLeft -> Error $ LeftoverCandidate $ P.Populace nextCandidate candidateLeft
				[] -> PatternComparator.acceptRest state
	else
		state >>> compareAsRequirementDefault (SomePattern self)

instance Show Literal where
	show Literal{literal} = Text.unpack literal

instance Messagable Literal where
	msg = show

instance Pattern Match.Literal Literal where
	parse = parseLiteral
	compareAsCandidate = compareAsCandidateLiteral
	compareAsRequirement = compareAsRequirementLiteral
	mustHavePrefix (Literal literal) = not $ Text.null literal
	mustHaveSuffix (Literal literal) = not $ Text.null literal
	canHavePrefix = Pattern.mustHavePrefix
	canHaveSuffix = Pattern.mustHaveSuffix
	canMatchEmpty (Literal literal) = Text.null literal
	startingSpaceStates (Literal literal) = if Text.null literal then
		mempty
	else do
		let headChar = Text.head literal
		Set.singleton $
			if isSpace headChar then SpaceState.Space
			else if isAlphaNum headChar then SpaceState.Word
			else SpaceState.Punctuation
	isOptional (Literal literal) = Text.null literal

compareAgainstNonLiteral
	:: Literal
	-> Text
	-> SomePattern
	-> ComparatorState
	-> P.Populace SomePattern
	-> ([SomePattern] -> ComparatorState -> ComparatorState)
	-> FallibleI Mismatch PatternComparator.Parses
compareAgainstNonLiteral self literal next state requirementP swapCandidate =
	case asPattern next :: Maybe CharClass of
		Just CharClass{..} -> if CC.has (Text.head literal) ranges negate then do
			let splitCandidate = next : SomePattern (Literal (Text.tail literal)) :
				tail state.rest.candidate
			PatternComparator.accept [next] $ swapCandidate splitCandidate state
		else
			compareAgainstSpace self literal next state requirementP swapCandidate
		Nothing -> compareAgainstSpace self literal next state requirementP swapCandidate

compareAgainstSpace
	:: Literal
	-> Text
	-> SomePattern
	-> ComparatorState
	-> P.Populace SomePattern
	-> ([SomePattern] -> ComparatorState -> ComparatorState)
	-> FallibleI Mismatch PatternComparator.Parses
compareAgainstSpace self literal next state requirementP swapCandidate =
	case (asPattern next :: Maybe Space, Text.uncons literal) of
		(Just Space, Just (firstChar, _)) -> if isSpace firstChar then do
			let splitCandidate = next : SomePattern (Literal (Text.dropWhile isSpace literal)) :
				tail state.rest.candidate
			PatternComparator.accept [next] $ swapCandidate splitCandidate state{ spaceState = SpaceState.Space }
		else
			Error $ Mismatch (SomePattern self) requirementP
		_ -> Error $ Mismatch (SomePattern self) requirementP

parse :: Literal -> Code.Parser Match.Literal
parse = parseLiteral
