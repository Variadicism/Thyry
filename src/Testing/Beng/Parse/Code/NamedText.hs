module Testing.Beng.Parse.Code.NamedText (
	testNamedText
) where

import Utils.Fallible
import Utils.Messaging (msg)
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (dualton)
import qualified Utils.Populace.Populace2 as P2
import Utils.Testing
import Utils.Tuples (mapSnd2)

import Testing.Beng.Utils.Mocks (ABCD(Divide), argOf, divide, locationOf, mockABCD)
import Testing.Beng.Utils.Parsers (MockParser, assertRest)

import Beng.Types.Operators (SomeOperator(..))
import Beng.Build.Context.Builders (cr2, intType, l, s)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers.Code ((>>>), (>\>), Parse, PrefixState(..), State(..), fileStartState, parses, target)
import qualified Beng.Parse.Patterns.NamedText as NamedText
import Beng.Types.Locations (Location(Builtin, BuiltinArg))
import Beng.Types.Parse.Patterns (And(..), CharClass(..), Delimited(..), NamedText(..), Or(..), SomePattern(..), Space(..))

import Data.Bifunctor (bimap)
import Data.Text.Lazy (Text)

-- private

type Pattern = SomePattern

assertCanBeEmpty :: Pattern -> Fallible ()
assertCanBeEmpty pattern = assert (NamedText.canBeEmpty pattern) $
	show pattern ++ " can be empty, but the tested code believes it can't!"

assertCannotBeEmpty :: Pattern -> Fallible ()
assertCannotBeEmpty pattern = assert (not $ NamedText.canBeEmpty pattern) $
	show pattern ++ " cannot be empty, but the tested code believes it can!"

a :: String -> Pattern
a name = argOf Divide name intType

parse :: Pattern -> MockParser Text
parse pattern = \code -> bimap msg parses $
	((fileStartState "NamedText test" mockABCD code){
		parent = Just $ SomeOperator divide,
		prefixState = Unneeded } >>>
	NamedText.parse NamedText { name = "Dividend Text", subpattern = pattern, decLoc = argLoc } >\>
	Match.toCode)
	where
		argLoc = do
			let (Builtin locationIndex) = locationOf Divide
			BuiltinArg "Dividend Text" locationIndex

assertParsed :: Text -> Parse Text -> Fallible ()
assertParsed expected actual = (expected, actual.target) `isEqualElse`
	"The named text was did not match what was expected!"

-- tests

testNamedText :: TestCategory
testNamedText = TestCategories "NamedText" [
	TestCategories "canBeEmpty" [
		PureTests "false" $ map (mapSnd2 assertCannotBeEmpty) [
			("non-empty l", l "G"),
			("CharClass", SomePattern $ CharClass (P.singleton $ cr2 'l') True),
			("cannot Or cannot", SomePattern $ Or $ dualton (l "h") (l "k")),
			("can And cannot", SomePattern $ And $ dualton (l "") (l "F")),
			("Delimited cannot", SomePattern Delimited { delimiter = l "JJ", delimitend = l "k" }),
			("Argument", a "Test")],
		PureTests "true" $ map (mapSnd2 assertCanBeEmpty) [
			("Space", SomePattern Space),
			("empty l", l ""),
			("cannot Or can", SomePattern $ Or $ dualton (l "h") (SomePattern Space)),
			("can And can", SomePattern $ And $ dualton (l "") (SomePattern Space)),
			("Delimited can", SomePattern Delimited { delimiter = l ",", delimitend = l "" })]],
	PureTests "parse" [
		("Literal then junk", do
			result <- assert1 "result" =<< parse (l "K") "Kh"
			assertParsed "K" result
			assertRest "h" result),
		("two results then junk", do
			(kResult, kkResult) <- assert2 "results" =<< parse (SomePattern $ Or $ dualton (l "K") (l "KK")) "KKp"
			assertParsed "K" kResult
			assertRest "Kp" kResult
			assertParsed "KK" kkResult
			assertRest "p" kkResult),
		-- I mocked `divide` as the parent op and Argument names must match the parent's.
		("op exactly", do
			result <- assert1 "result" =<< parse (a "Dividend") "b"
			assertParsed "b" result
			assertRest "" result),
		("op then junk", do
			result <- assert1 "result" =<< parse (a "Dividend") "b[]"
			assertParsed "b" result
			assertRest "[]" result),
		("ops spaced then junk", do
			result <- assert1 "result" =<< parse (SomePattern $ And $ P2.Populace2 (a "Dividend") s [a "Divisor"]) "a b 9"
			assertParsed "a b" result
			assertRest " 9" result)]]
