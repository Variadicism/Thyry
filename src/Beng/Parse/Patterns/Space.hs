module Beng.Parse.Patterns.Space (
	parse
) where

import Utils.Fallible hiding (Fallible)
import Utils.Lists (wrap)

import Beng.Errors (Fallible, parseError)
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers (Parser, ParseRunner, PrefixState(..), SpaceState(..), State(..), (@>), (@+>), (>|>), (>:>), (>\>), parseAll, takeAs)

import Data.Char (isAlphaNum, isSpace)
import Data.Text.Lazy (pack)
import qualified Data.Text.Lazy as Text

parse :: Parser Match
parse = "space pattern" @+> parseBoundary >|> parseSpaces where
	parseBoundary :: Parser Match
	parseBoundary = "parse word boundary" @> \state ->
		case Text.uncons state.rest of
			Nothing -> takeBoundary state
			Just (headChar, _) ->
				if state.spaceState == Space then
					takeBoundary state
				else if (state.spaceState == Word) /= (isAlphaNum headChar) then
					takeBoundary state
				else
					failBoundary headChar state

	failBoundary :: Char -> State -> Fallible a
	failBoundary nextChar state = Error $ parseError state $
		wrap "'" [nextChar] ++ " doesn't form a word boundary because it was preceded by a " ++
			show state.spaceState ++ " character.\n" ++
			"Note: in Beng, underscores are considered Punctuation."

	takeBoundary :: ParseRunner Match
	takeBoundary = takeAs "" (Match.Space "")

	parseSpaces :: Parser Match
	parseSpaces =
		parseSpace >:>
		parseAll parseSpace >\>
		\(firstSpace, moreSpaces) ->
			Match.Space $ Text.cons firstSpace $ pack moreSpaces

	parseSpace :: Parser Char
	parseSpace = "parse whitespace" @> \state ->
		case Text.uncons state.rest of
			Just (headChar, _) | isSpace headChar ->
				takeAs (Text.singleton headChar) headChar state{ prefixState = Unneeded }
			Just (headChar, _) -> Error $ parseError state $
				"Whitespace was expected where '" ++ [headChar] ++ "' was found!"
			Nothing -> Error $ parseError state
				"The end of the text was reached while trying to parse whitespace!"