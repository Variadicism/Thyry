module Beng.Parse.Patterns.Space (
	parse,
	parseSpace
) where

import Utils.Fallible hiding (Fallible)
import Utils.Lists (wrap)
import Utils.Messaging (Messagable(..))
import qualified Utils.Populace as P

import Beng.Errors (Fallible, parseError)
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>|>), (>:>), (>\>))
import qualified Beng.Parse.Parsers.Code as Code
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern, startingSpaceStates)
import qualified Beng.Types.Parse.Parsers.Code as TCode
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Parsers.Code (PrefixState(..))
import qualified Beng.Types.Parse.Parsers.Code as SpaceState (SpaceState(..))
import Beng.Types.Parse.Patterns (Comparison(..), ComparatorState(..), Mismatch(..), SomePattern(..), Space(..))

import Data.Char (isAlphaNum, isSpace)
import qualified Data.Set as Set
import Data.Text.Lazy (pack)
import qualified Data.Text.Lazy as T

parseSpace :: Code.Parser Match
parseSpace = "space pattern" @+> parseBoundary >|> parseSpaces

parseBoundary :: Code.Parser Match
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

takeBoundary :: Code.ParseRunner Match
takeBoundary = Code.takeAs "" (Match.Space "")

parseSpaces :: Code.Parser Match
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

compareAsSubSpace :: Space -> PatternComparator.Parser
compareAsSubSpace _ = "space comparator" @> \state ->
	case state.rest.requirement of
		[] -> case state.rest.candidate of
			[_] -> PatternComparator.accept [] state
			_ -> Error $ Mismatch (SomePattern Space) $ P.assume state.rest.candidate
		nextSuper:superLeft -> do
			let nextIsSpace = maybe False (const True) (asPattern nextSuper :: Maybe Space)
			let states = startingSpaceStates nextSuper
			let canSatisfyBoundary =
				not state.atStart &&
				not (Set.null states) &&
				all (TCode.formsBoundary state.spaceState) states
			if nextIsSpace then
				PatternComparator.accept [SomePattern Space] state
			else if canSatisfyBoundary then
				PatternComparator.accept [] state
			else
				Error $ Mismatch (SomePattern Space) $ P.Populace nextSuper superLeft

compareAsSuperSpace :: Space -> PatternComparator.Parser
compareAsSuperSpace _ = "space super comparator" @> \state -> do
	case state.rest.requirement of
		nextSuper:superLeft -> do
			let headSubIsSpace = case state.rest.candidate of
				nextSub:_ -> maybe False (const True) (asPattern nextSub :: Maybe Space)
				[] -> False
			let headSubConsumesWhitespace = case state.rest.candidate of
				nextSub:_ -> Set.member Code.Space $ startingSpaceStates nextSub
				[] -> False
			let canConsumeBoundary =
				not headSubIsSpace &&
				not headSubConsumesWhitespace &&
				not state.atStart &&
				case superLeft of
					next:_ -> do
						let states = startingSpaceStates next
						not (Set.null states) && all (TCode.formsBoundary state.spaceState) states
					[] -> False
			if canConsumeBoundary then
				state >>> ("consume boundary super Space" @>
						PatternComparator.acceptSuperOnly [nextSuper]) >:>
					PatternComparator.comparator >\> const ()
			else
				case state.rest.candidate of
					nextSub:_ -> dispatchCurrentSub nextSub state
					[] -> Error $ LeftoverSuper $ P.Populace nextSuper superLeft
		[] -> case state.rest.candidate of
			nextSub:subLeft -> Error $ LeftoverSub $ P.Populace nextSub subLeft
			[] -> PatternComparator.acceptRest state
	where
		dispatchCurrentSub (SomePattern pattern) state =
			state >>> TPattern.compareAsSub pattern >:> PatternComparator.comparator >\> const ()

instance Messagable Space where
	msg = show

instance TPattern.Pattern Space where
	parse _ = parseSpace
	compareAsSub = compareAsSubSpace
	compareAsSuper = compareAsSuperSpace
	showPatternWith _ _ = " "
	mustHavePrefix _ = False
	mustHaveSuffix _ = False
	canHavePrefix _ = True
	canHaveSuffix _ = True
	canMatchEmpty _ = True
	startingSpaceStates _ = Set.empty
	isOptional _ = False

parse :: Space -> Code.Parser Match
parse _ = parseSpace
