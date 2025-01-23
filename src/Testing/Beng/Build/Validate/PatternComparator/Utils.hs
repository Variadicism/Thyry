module Testing.Beng.Build.Validate.PatternComparator.Utils (
	assertSatisfies,
	assertDoesNotSatisfy
) where

import Utils.Fallible
import Utils.Messaging (msg)
import Utils.Testing (hasErrorElse)

import Testing.Beng.Utils.Mocks (mockNothing)

import Beng.Parse.Patterns (satisfies)
import Beng.Types.Parse.Patterns (Pattern)

assertSatisfies :: Pattern -> Pattern -> Fallible ()
assertSatisfies super sub = mapError msg $ (mockNothing, super) `satisfies` sub

assertDoesNotSatisfy :: Pattern -> Pattern -> Fallible ()
assertDoesNotSatisfy super sub = assertSatisfies super sub `hasErrorElse` "This should not have passed!"