module Testing.Beng.Parse.Or (
	testOr
) where

import Utils.Errors
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (assertState)

import Beng.Build.Context.Builders (l)
import Beng.Parse.Matches (Match, match, matchIndex)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((>\>), (<<<), SpaceState(..), Result(..), fileStartState)
import qualified Beng.Parse.Patterns.Or as Or

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

-- private

parse :: [Char] -> Text -> [Result (Int, Match)]
parse chars = \text ->
	Or.parse (map (l . Text.singleton) chars) >\>
	(\Match.Or{matchIndex,match} -> (matchIndex, match)) <<<
	fileStartState mockNothing text

assertMatch :: Int -> Char -> Result (Int, Match) -> Fallible ()
assertMatch index char result = do
	(Match.Literal $ Text.singleton char, snd result.target) `isEqualElse`
		"The subpattern match was unexpected!"
	(index, fst result.target) `isEqualElse` "The subpattern index was unexpected!"

-- tests

testOr :: TestCategory
testOr = PureTests "Or" [
	("exact solo", do
		result <- assert1 "result" $ parse "l" "l"
		assertMatch 0 'l' result),
	("unknown", do
		assert0 "results" $ parse "lm" ""),
	("solo match then unknown", do
		result <- assert1 "result" $ parse "m" "mk"
		assertMatch 0 'm' result
		assertState Word "k" result),
	("dual-option match then unknown", do
		result <- assert1 "result" $ parse "lm" "mk"
		assertMatch 1 'm' result
		assertState Word "k" result),
	("solo match then repetition", do
		result <- assert1 "result" $ parse "k" "kk"
		assertMatch 0 'k' result
		assertState Word "k" result),
	("match first of 3", do
		result <- assert1 "result" $ parse "lmn" "lo"
		assertMatch 0 'l' result
		assertState Word "o" result),
	("match middle of 3", do
		result <- assert1 "result" $ parse "lmn" "mn"
		assertMatch 1 'm' result
		assertState Word "n" result),
	("match last of 3", do
		result <- assert1 "result" $ parse "lmn" "n"
		assertMatch 2 'n' result
		assertState Word "" result)]