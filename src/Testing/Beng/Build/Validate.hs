module Testing.Beng.Build.Validate (
	testValidations
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator (testPatternComparator)
-- import Testing.Beng.Build.Validate.Typecheck (testTypeCheck)

testValidations :: TestCategory
testValidations = TestCategories "build validations" [
	testPatternComparator ]
	-- testTypeCheck ]