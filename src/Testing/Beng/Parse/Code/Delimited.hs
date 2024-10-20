module Testing.Beng.Parse.Code.Delimited (
	testDelimited
) where

import Utils.Fallible
import qualified Utils.Populace as P
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers ((!>>>), MockParser, assertState)

import Beng.Build.Context.Builders (l)
import Beng.Parse.Parsers.Code ((>\>), Parse, SpaceState(..), target)
import qualified Beng.Parse.Patterns.Delimited as Delimited
import Beng.Types.Parse.Matches (DelimitedTail(..), Match)
import qualified Beng.Types.Parse.Matches as Match

-- private

parse :: MockParser (Match, DelimitedTail)
parse = mockNothing !>>>
	Delimited.parse (l ",") (l "p") >\>
	\match@Match.Delimited{} -> (match.head, match.tail)

assertMatches :: Int -> Parse (Match, DelimitedTail) -> Fallible ()
assertMatches repetitions result = do
	(Match.Literal "p", fst result.target) `isEqualElse` "The head of the match was unexpected!"
	(expectedTail, snd result.target) `isEqualElse` "The tail of the match was unexpected!"
	where
		expectedTail = if repetitions == 0
			then DelimitedTailMissing []
			else DelimitedTailMatch $ P.assume $ replicate repetitions (Match.Literal ",", Match.Literal "p")

-- tests

testDelimited :: TestCategory
testDelimited = PureTests "Delimited" [
	("junk", do
		parse "k" `hasErrorElse` "Delimited may not parse random junk!"),
	("headless", do
		parse ",p,p" `hasErrorElse` "Delimited may not parse delimiters before its delimitend!"),
	("tailless", do
		result <- assert1 "result" =<< parse "p"
		assertMatches 0 result
		assertState Word "" result),
	("two heads", do
		result <- assert1 "result" =<< parse "pp"
		assertMatches 0 result
		assertState Word "p" result),
	("1 tail pair then extra head", do
		(headResult, resultWithTail) <- assert2 "results" =<< parse "p,pp"
		assertMatches 0 headResult
		assertState Word ",pp" headResult
		assertMatches 1 resultWithTail
		assertState Word "p" resultWithTail),
	("2 tail pairs", do
		(headResult, tail1Result, tail2Result) <- assert3 "results" =<< parse "p,p,p"
		assertMatches 0 headResult
		assertState Word ",p,p" headResult
		assertMatches 1 tail1Result
		assertState Word ",p" tail1Result
		assertMatches 2 tail2Result
		assertState Word "" tail2Result) ]