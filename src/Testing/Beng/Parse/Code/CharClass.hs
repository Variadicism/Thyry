module Testing.Beng.Parse.Code.CharClass (
	testCharClass
) where

import Utils.Fallible
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)
import Testing.Beng.Utils.Parsers ((!>>>), assertState)

import Beng.Build.Context.Builders (cr, cr2)
import Beng.Parse.Parsers.Code ((>\>), Parse, SpaceState(..))
import qualified Beng.Parse.Patterns.CharClass as CharClass
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Patterns (CharRange)

import Data.Text.Lazy (Text)

parse :: [CharRange] -> Bool -> Text -> Fallible (Populace (Parse ()))
parse ranges negate = mockNothing !>>>
	CharClass.parse (P.assume ranges) negate >\>
	\Match.CharClass{} -> ()

-- tests

testCharClass :: TestCategory
testCharClass = PureTests "CharClass" [
	("singleton exactly", do
		result <- assert1 "result" =<< parse [cr2 'h'] False "h"
		assertState Word "" result),
	("singleton then junk", do
		result <- assert1 "result" =<< parse [cr2 'c'] False "cj"
		assertState Word "j" result),
	("junk then match", do
		parse [cr2 'k'] False "mk" `hasErrorElse` "CharClass should not parse chars outside its range(s)!"),
	("one of two exactly", do
		result <- assert1 "result" =<< parse [cr2 'g', cr2 'b'] False "b"
		assertState Word "" result),
	("range exactly", do
		result <- assert1 "result" =<< parse [cr 'l' 'o'] False "m"
		assertState Word "" result),
	("range or one of two then junk", do
		result <- assert1 "result" =<< parse [cr 'A' 'F', cr2 'L', cr2 'P'] False "Bc"
		assertState Word "c" result),
	("one of two ranges repeated", do
		result <- assert1 "result" =<< parse [cr 'A' 'C', cr 'G' 'L'] False "II"
		assertState Word "I" result),
	("two ranges two chars negated repeated", do
		result <- assert1 "result" =<< parse [cr 'M' 'O', cr 'Q' 'S', cr2 'n', cr2 'r'] True "mm"
		assertState Word "m" result)]