module Testing.Beng.Parse.Code where

import Utils.Testing

import Testing.Beng.Parse.Code.And (testAnd)
import Testing.Beng.Parse.Code.CharClass (testCharClass)
import Testing.Beng.Parse.Code.Delimited (testDelimited)
import Testing.Beng.Parse.Code.Literal (testLiteral)
import Testing.Beng.Parse.Code.NamedText (testNamedText)
import Testing.Beng.Parse.Code.Or (testOr)
import Testing.Beng.Parse.Code.Space (testSpace)

testCode = TestCategories "parsing Patterns from code" [
	testLiteral,
	testCharClass,
	testSpace,
	testNamedText,
	testOr,
	testAnd,
	testDelimited ]