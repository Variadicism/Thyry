module Beng.Parse.Patterns.Space (
	parse
) where

import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers (Parser, ParseRunner, SpaceState(..), State(..), (@>), (@+>), (>|>), (>\>), parseWhile, takeAs, takeNone)

import Data.Char (isAlphaNum, isSpace)
import Data.Text.Lazy (pack)
import qualified Data.Text.Lazy as Text

parse :: Parser Match
parse = "space pattern" @+> parseBoundary >|> parseSpaces where
	parseBoundary :: Parser Match
	parseBoundary = "parse word boundary" @> \state ->
		case Text.uncons state.rest of
			Nothing -> takeBoundary state
			Just (headChar, _) -> case state.spaceState of
				Space -> takeBoundary state
				Word -> flip takeBoundaryIf state $ not $ isAlphaNum headChar
				Punctuation -> flip takeBoundaryIf state $ isAlphaNum headChar

	takeBoundary :: ParseRunner Match
	takeBoundary = takeBoundaryIf True

	takeBoundaryIf :: Bool -> ParseRunner Match
	takeBoundaryIf condition = if condition
		then takeAs "" (Match.Space "")
		else takeNone

	parseSpaces :: Parser Match
	parseSpaces =
		parseWhile parseSpace >\>
		Match.Space . pack

	parseSpace :: Parser Char
	parseSpace = "parse whitespace" @> \state ->
		case Text.uncons state.rest of
			Just (headChar, _) | isSpace headChar ->
				takeAs (Text.singleton headChar) headChar state
			_ -> takeNone state