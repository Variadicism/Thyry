module Beng.Parse.Patterns.Space (
	parse
) where

import Utils.Fallible hiding (Fallible)
import Utils.Lists (wrap)
import Utils.Messaging (Messagable(..))
import qualified Utils.Populace as P

import Beng.Errors (Fallible, parseError)
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>|>), (>:>), (>\>))
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

parseSpace :: Space -> Code.Parser Match
parseSpace _ = "space pattern" @+> parseBoundary >|> parseSpaces

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

compareFromSpace :: Space -> PatternComparator.Parser
compareFromSpace _ = "space comparator" @> \state ->
	case state.rest.super of
		[] -> case tail state.rest.sub of
			[] -> PatternComparator.accept [] state
			_ -> Error $ Mismatch (SomePattern Space) $ P.assume state.rest.sub
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

instance Messagable Space where
	msg = show

instance TPattern.Pattern Space where
	parse = parseSpace
	compareFrom = compareFromSpace
	showPatternWith _ _ = " "
	mustHavePrefix _ = False
	mustHaveSuffix _ = False
	canHavePrefix _ = True
	canHaveSuffix _ = True
	canMatchEmpty _ = True
	startingSpaceStates _ = Set.empty
	isOptional _ = False

parse :: Space -> Code.Parser Match
parse = parseSpace
