module Testing.Beng.Parse.CharClass (
	testCharClass
) where

import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers (assertState)

import Beng.Parse.Parsers ((>>>), (>\>), Result, SpaceState(..), fileStartState)
import qualified Beng.Parse.Patterns.CharClass as CharClass
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Types.Patterns (CharRange(..))

import Data.Text.Lazy (Text)

parse :: [CharRange] -> [Char] -> Bool -> Text -> [Result ()]
parse ranges chars negate text = fileStartState mockNothing text >>>
	CharClass.parse ranges chars negate >\>
	\Match.CharClass{} -> ()

-- tests

testCharClass :: TestCategory
testCharClass = PureTests "CharClass" [
	("singleton exactly", do
		result <- assert1 "result" $ parse [] "h" False "h"
		assertState Word "" result),
	("singleton then junk", do
		result <- assert1 "result" $ parse [] "c" False "cj"
		assertState Word "j" result),
	("junk then match", do
		assert0 "results" $ parse [] "k" False "mk"),
	("one of two exactly", do
		result <- assert1 "result" $ parse [] "gb" False "b"
		assertState Word "" result),
	("range exactly", do
		result <- assert1 "result" $ parse [CharRange 'l' 'o'] [] False "m"
		assertState Word "" result),
	("range or one of two then junk", do
		result <- assert1 "result" $ parse [CharRange 'A' 'F'] "LP" False "Bc"
		assertState Word "c" result),
	("one of two ranges repeated", do
		result <- assert1 "result" $ parse [CharRange 'A' 'C', CharRange 'G' 'L'] [] False "II"
		assertState Word "I" result),
	("two ranges two chars negated repeated", do
		result <- assert1 "result" $ parse [CharRange 'M' 'O', CharRange 'Q' 'S'] "nr" True "mm"
		assertState Word "m" result)]