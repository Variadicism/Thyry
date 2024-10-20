{-# LANGUAGE NoImplicitPrelude #-}

module Testing.Beng.Parse.Code.Or (
	testOr
) where

import Utils.Collective
import Utils.Fallible
import qualified Utils.Populace.Populace2 as P2
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers ((!>>>), MockParser, assertState)

import Beng.Build.Context.Builders (l)
import Beng.Parse.Matches (Match, match, matchIndex)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers.Code ((>\>), Parse, SpaceState(..), target)
import qualified Beng.Parse.Patterns.Or as Or

import qualified Data.Text.Lazy as Text

-- private

parse :: String -> MockParser (Int, Match)
parse chars = mockNothing !>>>
	Or.parse (P2.assume $ map (l . Text.singleton) chars) >\>
	\Match.Or{matchIndex,match} -> (matchIndex, match)

assertMatch :: Int -> Char -> Parse (Int, Match) -> Fallible ()
assertMatch index char result = do
	(Match.Literal $ Text.singleton char, snd result.target) `isEqualElse`
		"The subpattern match was unexpected!"
	(index, fst result.target) `isEqualElse` "The subpattern index was unexpected!"

-- tests

testOr :: TestCategory
testOr = PureTests "Or" [
	("junk", do
		parse "lm" "" `hasErrorElse` "Or Patterns should not parse unknown code successfully!"),
	("match then junk", do
		result <- assert1 "result" =<< parse "lm" "mk"
		assertMatch 1 'm' result
		assertState Word "k" result),
	("match then repetition", do
		result <- assert1 "result" =<< parse "kl" "kk"
		assertMatch 0 'k' result
		assertState Word "k" result),
	("match first of 3", do
		result <- assert1 "result" =<< parse "lmn" "lo"
		assertMatch 0 'l' result
		assertState Word "o" result),
	("match middle of 3", do
		result <- assert1 "result" =<< parse "lmn" "mn"
		assertMatch 1 'm' result
		assertState Word "n" result),
	("match last of 3", do
		result <- assert1 "result" =<< parse "lmn" "n"
		assertMatch 2 'n' result
		assertState Word "" result),
	("two matches on one char then junk", do
		(g0Result, g1Result) <- assert2 "results" =<< parse "ggk" "gt"
		assertMatch 0 'g' g0Result
		assertState Word "t" g0Result
		assertMatch 1 'g' g1Result
		assertState Word "t" g1Result)]