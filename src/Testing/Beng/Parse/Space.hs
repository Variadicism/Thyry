module Testing.Beng.Parse.Space (
	testSpace
) where

import Utils.Errors
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (assertState)

import Beng.Parse.Matches (text)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((>\>), (<<<), SpaceState(..), State(..), Result(..))
import qualified Beng.Parse.Patterns.Space as Space

import Data.Text.Lazy (Text)

-- private

parse :: SpaceState -> Text -> [Result Text]
parse spaceState = \text ->
	Space.parse >\>
	(\Match.Space{text} -> text) <<<
	State { context = mockNothing, spaceState, rest = text }

assertMatch :: Text -> Result Text -> Fallible ()
assertMatch text result = do
	(text, result.target) `isEqualElse` "The text matched was unexpected!"
	(result.target, result.parsed) `isEqualElse`
		"The text contained in the Space Match didn't match the text parsed in the Result!"

-- tests

testSpace :: TestCategory
testSpace = PureTests "Space" [
	("space exactly", do
		result <- assert1 "result" $ parse Word " "
		assertMatch " " result
		assertState Space "" result),
	("no boundary after word", do
		assert0 "results" $ parse Word "2"),
	("space then word after space", do
		result <- assert1 "result" $ parse Space " ad"
		assertMatch " " result
		assertState Space "ad" result),
	("space then word after word", do
		(nullResult, spaceResult) <- assert2 "results" $ parse Word " ad"
		assertMatch "" nullResult
		assertState Space " ad" nullResult
		assertMatch " " spaceResult
		assertState Space "ad" spaceResult),
	("two spaces after punctuation", do
		(nullResult, space1Result, space2Result) <- assert3 "results" $ parse Space "  lm"
		assertMatch "" nullResult
		assertState Space "  lm" nullResult
		assertMatch " " space1Result
		assertState Space " lm" space1Result
		assertMatch "  " space2Result
		assertState Space "lm" space2Result),
	("boundary on nothing after word", do
		result <- assert1 "result" $ parse Word ""
		assertMatch "" result
		assertState Word "" result),
	("boundary on nothing after punctuation", do
		result <- assert1 "result" $ parse Punctuation ""
		assertMatch "" result
		assertState Punctuation "" result) ]