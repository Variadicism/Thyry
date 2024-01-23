module Testing.Beng.Parse.Space (
	testSpace
) where

import Utils.Fallible
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (assertState)

import Beng.Parse.Matches (Match(text))
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((>\>), (<<<), SpaceState(..), Result(..), State(..), fileStartState)
import qualified Beng.Parse.Patterns.Space as Space

import Data.List (sort)
import Data.Text.Lazy (Text)

-- private

parse :: SpaceState -> Text -> [Result Text]
parse spaceState text = sort (
	Space.parse >\>
	(\Match.Space{text} -> text) <<<
	(fileStartState mockNothing text){ spaceState })

assertMatch :: Text -> Result Text -> Fallible ()
assertMatch text result = do
	(text, result.target) `isEqualElse` "The text matched was unexpected!"
	(result.target, result.parsed) `isEqualElse`
		"The text contained in the Space Match didn't match the text parsed in the Result!"

-- tests

testSpace :: TestCategory
testSpace = PureTests "Space" [
	("space exactly", do
		(nullResult, spaceResult) <- assert2 "result" $ parse Word " "
		assertMatch "" nullResult
		assertState Word " " nullResult
		assertMatch " " spaceResult
		assertState Space "" spaceResult),
	("no boundary after word", do
		assert0 "results" $ parse Word "2"),
	("space then word after space", do
		(nullResult, spaceResult) <- assert2 "results" $ parse Space " ad"
		assertMatch "" nullResult
		assertState Space " ad" nullResult
		assertMatch " " spaceResult
		assertState Space "ad" spaceResult),
	("space then word after word", do
		(nullResult, spaceResult) <- assert2 "results" $ parse Word " jk"
		assertMatch "" nullResult
		assertState Word " jk" nullResult
		assertMatch " " spaceResult
		assertState Space "jk" spaceResult),
	("two spaces after punctuation", do
		(nullResult, space1Result, space2Result) <- assert3 "results" $ parse Space "  lm"
		assertMatch "" nullResult
		assertState Space "  lm" nullResult
		assertMatch " " space1Result
		assertState Space " lm" space1Result
		assertMatch "  " space2Result
		assertState Space "lm" space2Result),
	-- TODO: add cases for starting text to parse with word or punctutation characters.
	("boundary on nothing after word", do
		result <- assert1 "result" $ parse Word ""
		assertMatch "" result
		assertState Word "" result),
	("boundary on nothing after punctuation", do
		result <- assert1 "result" $ parse Punctuation ""
		assertMatch "" result
		assertState Punctuation "" result) ]