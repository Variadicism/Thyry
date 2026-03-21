module Testing.Beng.Parse.Code.Space (
	testSpace
) where

import Utils.Fallible
import Utils.Messaging (msg)
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (MockParser, assertState)

import Beng.Parse.Matches (Match(text))
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers.Code ((>>>), (>\>), Parse, SpaceState(..), State(..), fileStartState, parsed, parses, target)
import qualified Beng.Parse.Patterns.Space as Space
import qualified Beng.Types.Parse.Patterns as Pattern

import Data.Bifunctor (bimap)
import Data.Text.Lazy (Text)

-- private

parse :: SpaceState -> MockParser Text
parse spaceState text = bimap msg parses (
	(fileStartState "Space test" mockNothing text){ spaceState } >>>
	Space.parse Pattern.Space >\>
	\Match.Space{text} -> text)

assertMatch :: Text -> Parse Text -> Fallible ()
assertMatch text result = do
	(text, result.target) `isEqualElse` "The text matched was unexpected!"
	(result.target, result.parsed) `isEqualElse`
		"The text contained in the Space Match didn't match the text parsed in the Result!"

-- tests

testSpace :: TestCategory
testSpace = PureTests "Space" [
	("space exactly", do
		(nullResult, spaceResult) <- assert2 "result" =<< parse Word " "
		assertMatch "" nullResult
		assertState Word " " nullResult
		assertMatch " " spaceResult
		assertState Space "" spaceResult),
	("no boundary after word", do
		parse Word "l" `hasErrorElse` "A word boundary should not be parsed following another word!"),
	("space then word after space", do
		(nullResult, spaceResult) <- assert2 "results" =<< parse Space " ad"
		assertMatch "" nullResult
		assertState Space " ad" nullResult
		assertMatch " " spaceResult
		assertState Space "ad" spaceResult),
	("space then word after word", do
		(nullResult, spaceResult) <- assert2 "results" =<< parse Word " jk"
		assertMatch "" nullResult
		assertState Word " jk" nullResult
		assertMatch " " spaceResult
		assertState Space "jk" spaceResult),
	("two spaces after punctuation", do
		(nullResult, space1Result, space2Result) <- assert3 "results" =<< parse Space "  lm"
		assertMatch "" nullResult
		assertState Space "  lm" nullResult
		assertMatch " " space1Result
		assertState Space " lm" space1Result
		assertMatch "  " space2Result
		assertState Space "lm" space2Result),
	-- TODO: add cases for starting text to parse with word or punctutation characters.
	("boundary on nothing after word", do
		result <- assert1 "result" =<< parse Word ""
		assertMatch "" result
		assertState Word "" result),
	("boundary on nothing after punctuation", do
		result <- assert1 "result" =<< parse Punctuation ""
		assertMatch "" result
		assertState Punctuation "" result) ]
