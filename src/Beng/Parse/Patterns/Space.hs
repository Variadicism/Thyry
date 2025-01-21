module Beng.Parse.Patterns.Space (
	parse,
	compareFrom
) where

import Utils.Fallible hiding (Fallible)
import Utils.Lists (wrap)
import qualified Utils.Populace as P
import qualified Utils.Text as Text

import Beng.Errors (Fallible, parseError)
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>|>), (>:>), (>\>))
import qualified Beng.Parse.Parsers.Code as Code
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import qualified Beng.Parse.Patterns.CharClass as CharClass
import Beng.Types.Parse.Parsers.Code (PrefixState(..))
import qualified Beng.Types.Parse.Parsers.Code as SpaceState (SpaceState(..))
import Beng.Types.Parse.Patterns (Mismatch(..), Pattern(..))

import Data.Char (isAlphaNum, isSpace)
import Data.Text.Lazy (pack)
import qualified Data.Text.Lazy as Text

parse :: Code.Parser Match
parse = "space pattern" @+> parseBoundary >|> parseSpaces where
	parseBoundary :: Code.Parser Match
	parseBoundary = "parse word boundary" @> \state ->
		case Text.uncons state.rest of
			Nothing -> takeBoundary state
			Just (headChar, _) ->
				if state.spaceState == SpaceState.Space then
					takeBoundary state
				else if (state.spaceState == SpaceState.Word) /= (isAlphaNum headChar) then
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
		parseSpace >:>
		Code.parseAll parseSpace >\>
		\(firstSpace, moreSpaces) ->
			Match.Space $ Text.cons firstSpace $ pack moreSpaces

	parseSpace :: Code.Parser Char
	parseSpace = "parse whitespace" @> \state ->
		case Text.uncons state.rest of
			Just (headChar, _) | isSpace headChar ->
				Code.takeAs (Text.singleton headChar) headChar state{ Code.prefixState = Unneeded }
			Just (headChar, _) -> Error $ parseError state $
				"Whitespace was expected where '" ++ [headChar] ++ "' was found!"
			Nothing -> Error $ parseError state
				"The end of the text was reached while trying to parse whitespace!"

compareFrom :: PatternComparator.Parser
compareFrom = "space comparator" @> \state -> case state.rest.super of
	[] -> case tail state.rest.sub of  -- If this is called, sub must start with a Space, so tail is safe.
		[] -> PatternComparator.accept [] state
		_ -> Error $ Mismatch Space $ P.assume state.rest.sub  -- length sub >= 2 here
	nextSuper:restSuper -> do
		let superP = P.Populace nextSuper restSuper
		case nextSuper of
			Literal{literal} -> case Text.maybeHead literal of
				Just c | isSpace c -> PatternComparator.accept [nextSuper] state
				_ -> Error $ Mismatch Space superP
			Space -> PatternComparator.accept [Space] state
			CharClass{..} ->
				if CharClass.any isSpace ranges negate
					then PatternComparator.accept [nextSuper] state
					else Error $ Mismatch Space superP
			_ -> Error $ Mismatch Space superP