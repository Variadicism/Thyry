module Testing.Beng.Parse.Code.Literal (
	testLiteral
) where

import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers ((!>>>), MockParser, assertState)

import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers.Code ((>\>), SpaceState(..))
import qualified Beng.Parse.Patterns.Literal as Literal
import Beng.Types.Parse.Patterns (Literal(..))

import Data.Text.Lazy (Text)

-- private

parse :: Text -> MockParser ()
parse literalText = mockNothing !>>>
	Literal.parse (Literal literalText) >\>
	\Match.Literal{} -> ()

parseL = parse "l"

-- tests

testLiteral :: TestCategory
testLiteral = PureTests "Literal" [
	("match exactly", do
		result <- assert1 "result" =<< parseL "l"
		assertState Word "" result),
	("match then unknown", do
		result <- assert1 "result" =<< parseL "lk"
		assertState Word "k" result),
	("junk then match", do
		parseL "kl" `hasErrorElse` "Literal should not parse text except its own!"),
	("match duplicated", do
		result <- assert1 "result" =<< parseL "ll"
		assertState Word "l" result),
	("empty from empty", do
		result <- assert1 "result" =<< parse "" ""
		assertState Space "" result),
	("empty then unknown", do
		result <- assert1 "result" =<< parse "" "j"
		assertState Space "j" result) ]
