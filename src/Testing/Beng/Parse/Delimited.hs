module Testing.Beng.Parse.Delimited (
	testDelimited
) where

import Utils.Fallible
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (assertState)

import Beng.Build.Context.Builders (l)
import Beng.Parse.Parsers ((<<<), (>\>), Result(..), SpaceState(..), fileStartState)
import qualified Beng.Parse.Patterns.Delimited as Delimited
import Beng.Parse.Types.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match

import Data.Text.Lazy (Text)

-- private

parse :: Text -> [Result (Match, [(Match, Match)])]
parse = \text ->
	Delimited.parse (l ",") (l "p") >\>
	(\match@Match.Delimited{} -> (match.head, match.tail)) <<<
	fileStartState "Delimited test" mockNothing text

assertMatches :: Int -> Result (Match, [(Match, Match)]) -> Fallible ()
assertMatches repetitions result = do
	(Match.Literal "p", fst result.target) `isEqualElse` "The head of the match was unexpected!"
	(expectedTail, snd result.target) `isEqualElse` "The tail of the match was unexpected!"
	where
		expectedTail = replicate repetitions (Match.Literal ",", Match.Literal "p")

-- tests

testDelimited :: TestCategory
testDelimited = PureTests "Delimited" [
	("unknown", do
		assert0 "results" $ parse "k"),
	("headless", do
		assert0 "results" $ parse ",p,p"),
	("tailless", do
		result <- assert1 "result" $ parse "p"
		assertMatches 0 result
		assertState Word "" result),
	("two heads", do
		result <- assert1 "result" $ parse "pp"
		assertMatches 0 result
		assertState Word "p" result),
	("1 tail pair then extra head", do
		(headResult, resultWithTail) <- assert2 "results" $ parse "p,pp"
		assertMatches 0 headResult
		assertState Word ",pp" headResult
		assertMatches 1 resultWithTail
		assertState Word "p" resultWithTail),
	("2 tail pairs", do
		(headResult, tail1Result, tail2Result) <- assert3 "results" $ parse "p,p,p"
		assertMatches 0 headResult
		assertState Word ",p,p" headResult
		assertMatches 1 tail1Result
		assertState Word ",p" tail1Result
		assertMatches 2 tail2Result
		assertState Word "" tail2Result) ]