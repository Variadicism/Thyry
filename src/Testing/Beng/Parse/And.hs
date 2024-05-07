module Testing.Beng.Parse.And (
	testAnd
) where

import Utils.Fallible
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers ((!>>>), MockParser, assertState)

import Beng.Build.Context.Builders (l, s, patConcat)
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((>\>), Parse(..), SpaceState(..))
import qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Patterns (Pattern)

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

-- private

parse :: [Pattern] -> MockParser (Populace Match)
parse subpatterns = mockNothing !>>>
	Pattern.parse (patConcat subpatterns) >\>
	Match.getSubmatches

parseLits :: [Char] -> Text -> Fallible (Populace (Parse (Populace Match)))
parseLits chars = parse $ map (l . Text.singleton) chars

assertMatches :: [Match] -> Parse (Populace Match) -> Fallible ()
assertMatches matches result =
	(P.assume matches, result.target) `isEqualElse` "The subpattern matches were unexpected!"

assertLitMatches :: [Char] -> (Parse (Populace Match) -> Fallible ())
assertLitMatches chars =
	assertMatches $ map (Match.Literal . Text.singleton) chars

lM :: (Text -> Match)
lM = Match.Literal

orM :: Match -> Int -> Match
orM match matchIndex = Match.Or{ matchIndex, match, misses = [] }

sM :: (Text -> Match)
sM = Match.Space

gThenOptionalR :: [Pattern]
gThenOptionalR = [l "g", Pattern.Or $ P2.dualton (l "") (l "r")]

optionalsKAndJ :: [Pattern]
optionalsKAndJ = [Pattern.Or $ P2.dualton (l "k") (l ""), Pattern.Or $ P2.dualton (l "") (l "j")]

sSpaceP :: [Pattern]
sSpaceP = [l "s", s, l "p"]

-- tests

testAnd :: TestCategory
testAnd = TestCategories "And" [
	PureTests "Literal subpatterns" [
		("unknown", do
			parseLits "k" "l" `hasErrorElse` "An And pattern should not successfully parse unknown code!"),
		("one subpattern exactly", do
			result <- assert1 "result" =<< parseLits "k" "k"
			assertLitMatches "k" result
			assertState Word "" result),
		("one subpattern then unknown", do
			result <- assert1 "result" =<< parseLits "k" "kp"
			assertLitMatches "k" result
			assertState Word "p" result),
		("one subpattern then repetition", do
			result <- assert1 "result" =<< parseLits "k" "kk"
			assertLitMatches "k" result
			assertState Word "k" result),
		("multiple subpatterns then unknown", do
			result <- assert1 "result" =<< parseLits "klp" "klpn"
			assertLitMatches "klp" result
			assertState Word "n" result)],
	PureTests "complex subpatterns" [
		("G then optional R exactly", do
			(aResult, arResult) <- assert2 "results" =<<
				parse gThenOptionalR "gr"
			assertMatches [lM "g", orM (lM "") 0] aResult
			assertState Word "r" aResult
			assertMatches [lM "g", orM (lM "r") 1] arResult
			assertState Word "" arResult),
		("G then optional R then unknown", do
			(aResult, arResult) <- assert2 "results" =<<
				parse gThenOptionalR "grk"
			assertMatches [lM "g", orM (lM "") 0] aResult
			assertState Word "rk" aResult
			assertMatches [lM "g", orM (lM "r") 1] arResult
			assertState Word "k" arResult),
		("G missing optional R exactly", do
			result <- assert1 "result" =<<
				parse gThenOptionalR "g"
			assertMatches [lM "g", orM (lM "") 0] result
			assertState Word "" result),
		("K missing J exactly", do
			(kResult, nullResult) <- assert2 "results" =<<
				parse optionalsKAndJ "k"
			assertMatches [orM (lM "k") 0, orM (lM "") 0] kResult
			assertState Word "" kResult
			assertMatches [orM (lM "") 1, orM (lM "") 0] nullResult
			assertState Space "k" nullResult),
		("missing K given J then extra K", do
			(nullResult, jResult) <- assert2 "results" =<<
				parse optionalsKAndJ "jk"
			assertMatches [orM (lM "") 1, orM (lM "j") 1] jResult
			assertState Word "k" jResult
			assertMatches [orM (lM "") 1, orM (lM "") 0] nullResult
			assertState Space "jk" nullResult),
		("SP without space exactly", do
			parse sSpaceP "sp" `hasErrorElse` "A Space cannot parse a boundary between two words!"),
		("S space P exactly", do
			result <- assert1 "result" =<< parse sSpaceP "s p"
			assertMatches [lM "s", sM " ", lM "p"] result
			assertState Word "" result),
		("S 3 spaces P then extra spaces", do
			result <- assert1 "result" =<< parse sSpaceP "s   p  "
			assertMatches [lM "s", sM "   ", lM "p"] result
			assertState Word "  " result)]]