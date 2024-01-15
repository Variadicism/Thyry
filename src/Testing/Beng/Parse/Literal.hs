module Testing.Beng.Parse.Literal (
	testLiteral
) where

import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (assertState)

import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((>\>), (<<<), SpaceState(..), Result(..), fileStartState)
import qualified Beng.Parse.Patterns.Literal as Literal

import Data.Text.Lazy (Text)

-- private

parse :: Text -> Text -> [Result ()]
parse literalText = \text ->
	Literal.parse literalText >\>
	(\Match.Literal{} -> ()) <<<
	fileStartState mockNothing text

parseL = parse "l"

-- tests

testLiteral :: TestCategory
testLiteral = PureTests "Literal" [
	("match exactly", do
		result <- assert1 "result" $ parseL "l"
		assertState Word "" result),
	("match then unknown", do
		result <- assert1 "result" $ parseL "lk"
		assertState Word "k" result),
	("unknown then match", do
		assert0 "results" $ parseL "kl"),
	("match duplicated", do
		result <- assert1 "result" $ parseL "ll"
		assertState Word "l" result),
	("empty from empty", do
		result <- assert1 "result" $ parse "" ""
		assertState Space "" result),
	("empty then unknown", do
		result <- assert1 "result" $ parse "" "j"
		assertState Space "j" result) ]