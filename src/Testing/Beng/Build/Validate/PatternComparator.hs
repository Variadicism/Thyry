module Testing.Beng.Build.Validate.PatternComparator (
	testPatternComparator
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.And (testAnd)
import Testing.Beng.Build.Validate.PatternComparator.Arg (testArg)
import Testing.Beng.Build.Validate.PatternComparator.CharClass (testCharClass)
import Testing.Beng.Build.Validate.PatternComparator.Delimited (testDelimited)
import Testing.Beng.Build.Validate.PatternComparator.Literal (testLiteral)
import Testing.Beng.Build.Validate.PatternComparator.NamedText (testNamedText)
import Testing.Beng.Build.Validate.PatternComparator.Or (testOr)

-- private

testPatternComparator :: TestCategory
testPatternComparator = TestCategories "pattern comparator" [
	testAnd,
	testArg,
	testCharClass,
	testDelimited,
	testLiteral,
	testNamedText,
	testOr ]