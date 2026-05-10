module Beng.Parse.Patterns.Space (
	parse,
	parseSpace
) where

import Utils.Fallible hiding (Fallible)
import Utils.Lists (wrap)
import Utils.Messaging (Messagable(..))
import qualified Utils.Populace as P

import Beng.Errors (Fallible, parseError)
import {-# SOURCE #-} Beng.Parse.Matches ()
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>|>), (>:>), (>\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (
	accept,
	acceptRequirementOnly,
	acceptRest,
	comparator)
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern, startingSpaceStates)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Parsers.PatternComparator (
	Comparator,
	Comparison(..),
	ComparatorState(..))
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Types.Parse.Parsers.Code (PrefixState(..))
import qualified Beng.Types.Parse.Matches as Match
import qualified Beng.Types.Parse.Parsers.Code as SpaceState (SpaceState(..))
import Beng.Types.Parse.Patterns (
	Mismatch(..),
	Pattern,
	SomePattern(..),
	Space(..))

import Data.Char (isAlphaNum, isSpace)
import qualified Data.Set as Set
import Data.Text.Lazy (pack)
import qualified Data.Text.Lazy as T

parseSpace :: Code.Parser Match.Space
parseSpace = "space pattern" @+> parseBoundary >|> parseSpaces

parseBoundary :: Code.Parser Match.Space
parseBoundary = "parse word boundary" @> \state ->
	case T.uncons state.rest of
		Nothing -> takeBoundary state
		Just (headChar, _) ->
			if state.spaceState == SpaceState.Space || (state.spaceState == SpaceState.Word) /= isAlphaNum headChar then
				takeBoundary state
			else
				failBoundary headChar state

failBoundary :: Char -> Code.State -> Fallible a
failBoundary nextChar state = Error $ parseError state $
	wrap "'" [nextChar] ++ " doesn't form a word boundary because it was preceded by a " ++
		show state.spaceState ++ " character.\n" ++
		"Note: in Beng, underscores are considered Punctuation."

takeBoundary :: Code.ParseRunner Match.Space
takeBoundary = Code.takeAs "" $ Match.Space ""

parseSpaces :: Code.Parser Match.Space
parseSpaces =
	parseSingleSpace >:>
	Code.parseAll parseSingleSpace >\>
	\(firstSpace, moreSpaces) ->
		Match.Space $ T.cons firstSpace $ pack moreSpaces

parseSingleSpace :: Code.Parser Char
parseSingleSpace = "parse whitespace" @> \state ->
	case T.uncons state.rest of
		Just (headChar, _) -> if isSpace headChar then
			Code.takeAs (T.singleton headChar) headChar state{ Code.prefixState = Unneeded }
		else
			Error $ parseError state $
				"Whitespace was expected where '" ++ [headChar] ++ "' was found!"
		Nothing -> Error $ parseError state
			"The end of the text was reached while trying to parse whitespace!"

compareAsCandidateSpace :: Space -> Comparator
compareAsCandidateSpace _ = "space comparator" @> \state ->
	case state.rest.requirement of
		[] -> case state.rest.candidate of
			[_] -> accept [] state
			_ -> Error $ Mismatch (SomePattern Space) $ P.assume state.rest.candidate
		nextRequirement:requirementLeft -> do
			let nextIsSpace = maybe False (const True) (asPattern nextRequirement :: Maybe Space)
			let states = startingSpaceStates nextRequirement
			let canSatisfyBoundary =
				not state.atStart &&
				not (Set.null states) &&
				all (Code.formsBoundary state.spaceState) states
			if nextIsSpace then
				accept [SomePattern Space] state
			else if canSatisfyBoundary then
				accept [] state
			else
				Error $ Mismatch (SomePattern Space) $ P.Populace nextRequirement requirementLeft

compareAsRequirementSpace :: Space -> Comparator
compareAsRequirementSpace _ = "space requirement comparator" @> \state -> do
	case state.rest.requirement of
		nextRequirement:requirementLeft -> do
			let headCandidateIsSpace = case state.rest.candidate of
				nextCandidate:_ -> maybe False (const True) (asPattern nextCandidate :: Maybe Space)
				[] -> False
			let headCandidateConsumesWhitespace = case state.rest.candidate of
				nextCandidate:_ -> Set.member Code.Space $ startingSpaceStates nextCandidate
				[] -> False
			let canConsumeBoundary =
				not headCandidateIsSpace &&
				not headCandidateConsumesWhitespace &&
				not state.atStart &&
				case requirementLeft of
					next:_ -> do
						let states = startingSpaceStates next
						not (Set.null states) && all (Code.formsBoundary state.spaceState) states
					[] -> False
			if canConsumeBoundary then
				state >>> ("consume boundary requirement Space" @> acceptRequirementOnly [nextRequirement]) >:>
					comparator >\> const ()
			else
				case state.rest.candidate of
					nextCandidate:_ -> dispatchCurrentCandidate nextCandidate state
					[] -> Error $ LeftoverRequirement $ P.Populace nextRequirement requirementLeft
		[] -> case state.rest.candidate of
			nextCandidate:candidateLeft -> Error $ LeftoverCandidate $ P.Populace nextCandidate candidateLeft
			[] -> acceptRest state
	where
		dispatchCurrentCandidate (SomePattern pattern) state =
			state >>> Pattern.compareAsCandidate pattern >:> comparator >\> const ()

instance Show Space where
	show _ = " "

instance Messagable Space where
	msg = show

instance Pattern Match.Space Space where
	parse _ = parseSpace
	compareAsCandidate = compareAsCandidateSpace
	compareAsRequirement = compareAsRequirementSpace
	mustHavePrefix _ = False
	mustHaveSuffix _ = False
	canHavePrefix _ = True
	canHaveSuffix _ = True
	canMatchEmpty _ = True
	startingSpaceStates _ = Set.empty
	isOptional _ = False

parse :: Space -> Code.Parser Match.Space
parse _ = parseSpace
