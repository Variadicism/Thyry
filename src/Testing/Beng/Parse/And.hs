module Testing.Beng.Parse.And (
	testAnd
) where

import Utils.Errors
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (assertState)

import Beng.Build.Context.Builders (l)
import Beng.Parse.Matches (Match, matches)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((>\>), (<<<), SpaceState(..), State(..), Result(..))
import qualified Beng.Parse.Patterns.And as And

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

-- private

parse :: [Char] -> Text -> [Result [Match]]
parse chars = \text ->
	And.parse (map (l . Text.singleton) chars) >\>
	(\Match.And{matches} -> matches) <<<
	State { context = mockNothing, spaceState = Space, rest = text }

assertMatches :: [Char] -> Result [Match] -> Fallible ()
assertMatches chars result =
	(map (Match.Literal . Text.singleton) chars, result.target) `isEqualElse`
		"The subpattern matches were unexpected!"

-- tests

testAnd :: TestCategory
testAnd = PureTests "And" [
	("unknown", do
		assert0 "results" $ parse "k" "l"),
	("one subpattern exactly", do
		result <- assert1 "result" $ parse "k" "k"
		assertMatches "k" result
		assertState Word "" result),
	("one subpattern then unknown", do
		result <- assert1 "result" $ parse "k" "kp"
		assertMatches "k" result
		assertState Word "p" result),
	("one subpattern then repetition", do
		result <- assert1 "result" $ parse "k" "kk"
		assertMatches "k" result
		assertState Word "k" result),
	("multiple subpatterns then unknown", do
		result <- assert1 "result" $ parse "klp" "klpn"
		assertMatches "klp" result
		assertState Word "n" result),
	("no subpatterns", do
		result <- assert1 "result" $ parse "" "n"
		assertMatches "" result
		assertState Space "n" result)]
	-- TODO: add cases for subpatterns that can have multiple Results.
