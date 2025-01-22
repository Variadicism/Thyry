module Testing.Beng.Build.Validate.PatternComparator (
	testPatternComparator
) where

import Utils.Fallible
import Utils.Messaging (msg)
import Utils.Testing

import Testing.Beng.Utils.Mocks (mockNothing)

import Beng.Build.Context.Builders (l, patConcat)
import Beng.Parse.Patterns (satisfies)
import Beng.Types.Parse.Patterns (Pattern)

-- private

assertSatisfies :: Pattern -> Pattern -> Fallible ()
assertSatisfies super sub = mapError msg $ (mockNothing, super) `satisfies` sub

testPatternComparator :: TestCategory
testPatternComparator = TestCategories "pattern comparator" [
	PureTests "Literal" [
		("exact", assertSatisfies (l "if") (l "if")),
		("piece by piece", assertSatisfies (l "if") (patConcat [l "i", l "f"])) ]]