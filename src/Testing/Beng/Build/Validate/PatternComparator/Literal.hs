module Testing.Beng.Build.Validate.PatternComparator.Literal (
	testLiteral
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (c, cr, e, l, s, optional, patConcat)

testLiteral :: TestCategory
testLiteral = TestCategories "Literal candidate" [
	TestCategories "Literal requirement" [
		PureTests "satisfies" [
			("exact", assertSatisfies (l "if") (l "if")),
			("requirement split", assertSatisfies (patConcat [l "i", l "f"]) (l "if")),
			("candidate split", assertSatisfies (l "if") (patConcat [l "i", l "f"])) ],
		PureTests "does not satisfy" [
			("total mismatch", assertDoesNotSatisfy (l "then") (l "if")),
			("prefix but not total", assertDoesNotSatisfy (l "i") (l "if")) ],
	PureTests "CharClass requirement" [
		("satisfies", c [cr 'a' 'b'] `assertSatisfies` l "a"),
		("does not satisfy", c [cr '0' '9'] `assertDoesNotSatisfy` l "a") ],
	PureTests "Space requirement" [
		("satisfies", patConcat [s, l "test"] `assertSatisfies` l " test"),
		("err does not satisfy", patConcat [s, l "test"] `assertDoesNotSatisfy` l "test") ],
	PureTests "optional requirement sequence" [
		("skips optional middle", patConcat [l "a", optional (l "b"), l "c"] `assertSatisfies` l "ac"),
		("matches optional middle", patConcat [l "a", optional (l "b"), l "c"] `assertSatisfies` l "abc") ],
	PureTests "direct optional requirement sequence" [
		("Space middle", patConcat [l "a", s, l "c"] `assertDoesNotSatisfy` l "ac"),
		("Space boundary and whitespace",
			patConcat [l "a", s, l "/", s, l "c"] `assertSatisfies` l "a /c"),
		("Space boundary before letters CharClass",
			patConcat [l "a", s, l "/", s, c [cr 'a' 'z', cr 'A' 'Z']] `assertSatisfies` l "a /c"),
		("Space boundary before mixed CharClass",
			patConcat [l "a", s, l "/", s, c [cr 'a' 'z', cr 'A' 'Z', cr '-' '-']] `assertDoesNotSatisfy` l "a /c"),
		("empty Literal middle", patConcat [l "a", e, l "c"] `assertSatisfies` l "ac") ],
	PureTests "disparate" [
		("Space", assertDoesNotSatisfy s (l "if")) ]]]
