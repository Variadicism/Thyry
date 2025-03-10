module Testing.Beng.Build.Validate.PatternComparator.Utils (
	assertSatisfies,
	assertDoesNotSatisfy
) where

import Utils.Fallible
import Utils.Messaging (msg)
import Utils.Testing (hasErrorElse)

import Testing.Beng.Utils.Mocks (mockNothing)

import Beng.Parse.Patterns (satisfies)
import qualified Beng.Build.TypeTest as TypeTest
import Beng.Types.Parse.Patterns (Pattern)
import Beng.Types.Things (Thing(One))

assertSatisfies :: Pattern -> Pattern -> Fallible ()
assertSatisfies super sub = do
	 let test = TypeTest.fromContext mockNothing One One
	 mapError msg $ (test, super) `satisfies` sub

assertDoesNotSatisfy :: Pattern -> Pattern -> Fallible ()
assertDoesNotSatisfy super sub = assertSatisfies super sub `hasErrorElse` "This should not have passed!"