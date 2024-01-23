module Testing.Beng.Parse.And (
	testAnd
) where

import Utils.Fallible
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (assertState)

import Beng.Build.Context.Builders (l)
import Beng.Parse.Matches (Match, matches)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((>\>), (<<<), SpaceState(..), Result(..), fileStartState)
import qualified Beng.Parse.Patterns.And as And
import Beng.Parse.Types.Patterns (Pattern)
import qualified Beng.Parse.Types.Patterns as Pattern

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

-- private

parse subpatterns = \text ->
	And.parse subpatterns >\>
	(\Match.And{matches} -> matches) <<<
	fileStartState "And test" mockNothing text

parseLits :: [Char] -> Text -> [Result [Match]]
parseLits chars = parse $ map (l . Text.singleton) chars

assertMatches :: [Match] -> Result [Match] -> Fallible ()
assertMatches matches result =
	(matches, result.target) `isEqualElse` "The subpattern matches were unexpected!"

assertLitMatches :: [Char] -> (Result [Match] -> Fallible ())
assertLitMatches chars =
	assertMatches $ map (Match.Literal . Text.singleton) chars

lM :: (Text -> Match)
lM = Match.Literal

orM :: Match -> Int -> Match
orM match matchIndex = Match.Or{ matchIndex, match, misses = [] }

sM :: (Text -> Match)
sM = Match.Space

gThenOptionalR :: [Pattern]
gThenOptionalR = [l "g", Pattern.Or [l "", l "r"]]

optionalsKAndJ :: [Pattern]
optionalsKAndJ = [Pattern.Or [l "k", l ""], Pattern.Or [l "", l "j"]]

sSpaceP :: [Pattern]
sSpaceP = [l "s", Pattern.Space, l "p"]

-- tests

testAnd :: TestCategory
testAnd = TestCategories "And" [
	PureTests "Literal subpatterns" [
		("unknown", do
			assert0 "results" $ parseLits "k" "l"),
		("one subpattern exactly", do
			result <- assert1 "result" $ parseLits "k" "k"
			assertLitMatches "k" result
			assertState Word "" result),
		("one subpattern then unknown", do
			result <- assert1 "result" $ parseLits "k" "kp"
			assertLitMatches "k" result
			assertState Word "p" result),
		("one subpattern then repetition", do
			result <- assert1 "result" $ parseLits "k" "kk"
			assertLitMatches "k" result
			assertState Word "k" result),
		("multiple subpatterns then unknown", do
			result <- assert1 "result" $ parseLits "klp" "klpn"
			assertLitMatches "klp" result
			assertState Word "n" result),
		("no subpatterns", do
			result <- assert1 "result" $ parseLits "" "n"
			assertLitMatches "" result
			assertState Space "n" result)],
	PureTests "complex subpatterns" [
		("G then optional R exactly", do
			(aResult, arResult) <- assert2 "results" $
				parse gThenOptionalR "gr"
			assertMatches [lM "g", orM (lM "") 0] aResult
			assertState Word "r" aResult
			assertMatches [lM "g", orM (lM "r") 1] arResult
			assertState Word "" arResult),
		("G then optional R then unknown", do
			(aResult, arResult) <- assert2 "results" $
				parse gThenOptionalR "grk"
			assertMatches [lM "g", orM (lM "") 0] aResult
			assertState Word "rk" aResult
			assertMatches [lM "g", orM (lM "r") 1] arResult
			assertState Word "k" arResult),
		("G missing optional R exactly", do
			result <- assert1 "result" $
				parse gThenOptionalR "g"
			assertMatches [lM "g", orM (lM "") 0] result
			assertState Word "" result),
		("K missing J exactly", do
			(kResult, nullResult) <- assert2 "results" $
				parse optionalsKAndJ "k"
			assertMatches [orM (lM "k") 0, orM (lM "") 0] kResult
			assertState Word "" kResult
			assertMatches [orM (lM "") 1, orM (lM "") 0] nullResult
			assertState Space "k" nullResult),
		("missing K given J then extra K", do
			(nullResult, jResult) <- assert2 "results" $
				parse optionalsKAndJ "jk"
			assertMatches [orM (lM "") 1, orM (lM "j") 1] jResult
			assertState Word "k" jResult
			assertMatches [orM (lM "") 1, orM (lM "") 0] nullResult
			assertState Space "jk" nullResult),
		("SP without space exactly", do
			assert0 "results" $ parse sSpaceP "sp"),
		("S space P exactly", do
			result <- assert1 "result" $ parse sSpaceP "s p"
			assertMatches [lM "s", sM " ", lM "p"] result
			assertState Word "" result),
		("S 3 spaces P then extra spaces", do
			result <- assert1 "result" $ parse sSpaceP "s   p  "
			assertMatches [lM "s", sM "   ", lM "p"] result
			assertState Word "  " result)]]
