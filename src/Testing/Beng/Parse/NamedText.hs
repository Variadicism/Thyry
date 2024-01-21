module Testing.Beng.Parse.NamedText (
	testNamedText
) where

import Utils.Errors
import Utils.Testing
import Utils.Tuples (mapSnd2)

import Testing.Beng.Utils.Mocks (mockABMath, divide)
import Testing.Beng.Utils.Parsers (assertRest)

import Beng.Build.Types.Cards (Card(..))
import Beng.Build.Context.Builders (a, l, s)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((>>>), (>\>), fileStartState, PrefixState(..), Result(..), State(..))
import qualified Beng.Parse.Patterns.NamedText as NamedText
import Beng.Parse.Patterns (Pattern(..))

import Data.Text.Lazy (Text)

-- private

assertCanBeEmpty :: Pattern -> Fallible ()
assertCanBeEmpty pattern = assert (NamedText.canBeEmpty pattern) $
	show pattern ++ " can be empty, but the tested code believes it can't!"

assertCannotBeEmpty :: Pattern -> Fallible ()
assertCannotBeEmpty pattern = assert (not $ NamedText.canBeEmpty pattern) $
	show pattern ++ " cannot be empty, but the tested code believes it can!"

parse :: Pattern -> Text -> [Result Text]
parse pattern code =
	(fileStartState mockABMath code){
		parent = Just $ DefCard divide,
		prefixState = Unneeded } >>>
	NamedText.parse "Dividend Text" pattern >\>
	\Match.NamedText{match} -> Match.getText match

assertParsed :: Text -> Result Text -> Fallible ()
assertParsed expected actual = (expected, actual.target) `isEqualElse`
	"The named text was did not match what was expected!"

-- tests

testNamedText :: TestCategory
testNamedText = TestCategories "NamedText" [
	TestCategories "canBeEmpty" [
		PureTests "false" $ map (mapSnd2 assertCannotBeEmpty) [
			("non-empty l", l "G"),
			("CharClass", CharClass ['l'] [] True),
			("cannot Or cannot", Or [l "h", l "k"]),
			("can And cannot", And [l "", l "F"]),
			("Delimited cannot", Delimited (l "JJ") (l "k")),
			("Argument", Argument { name = "Test" })],
		PureTests "true" $ map (mapSnd2 assertCanBeEmpty) [
			("Space", Space),
			("empty l", l ""),
			("cannot Or can", Or [l "h", Space]),
			("can And can", And [l "", Space]),
			("Delimited can", Delimited (l ",") (l ""))]],
	PureTests "parse" [
		("Literal then junk", do
			result <- assert1 "result" $ parse (l "K") "Kh"
			assertParsed "K" result
			assertRest "h" result),
		("two results then junk", do
			(kResult, kkResult) <- assert2 "results" $ parse (Or [l "K", l "KK"]) "KKp"
			assertParsed "K" kResult
			assertRest "Kp" kResult
			assertParsed "KK" kkResult
			assertRest "p" kkResult),
		-- I mocked `divide` as the parent op and Argument names must match the parent's.
		("op exactly", do
			result <- assert1 "result" $ parse (a "Dividend") "b"
			assertParsed "b" result
			assertRest "" result),
		("op then junk", do
			result <- assert1 "result" $ parse (a "Dividend") "b[]"
			assertParsed "b" result
			assertRest "[]" result),
		("ops spaced then junk", do
			result <- assert1 "result" $ parse (And [a "Dividend", s, a "Divisor"]) "a b 9"
			assertParsed "a b" result
			assertRest " 9" result)]]