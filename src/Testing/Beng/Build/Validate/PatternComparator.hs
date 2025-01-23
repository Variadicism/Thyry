module Testing.Beng.Build.Validate.PatternComparator (
	testPatternComparator
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.And (testAnd)
import Testing.Beng.Build.Validate.PatternComparator.Literal (testLiteral)

-- private

testPatternComparator :: TestCategory
testPatternComparator = TestCategories "pattern comparator" [
	testAnd,
	testLiteral ]