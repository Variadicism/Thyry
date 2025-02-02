module Testing.Beng.Build.Validate.PatternComparator.Literal (
	testLiteral
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (c, cr, l, patConcat)
import Beng.Types.Parse.Patterns (Pattern(Space))

testLiteral :: TestCategory
testLiteral = TestCategories "Literal sub" [
	TestCategories "Literal super" [
		PureTests "satisfies" [
			("exact", assertSatisfies (l "if") (l "if")),
			("super split", assertSatisfies (patConcat [l "i", l "f"]) (l "if")),
			("sub split", assertSatisfies (l "if") (patConcat [l "i", l "f"])) ],
		PureTests "does not satisfy" [
			("total mismatch", assertDoesNotSatisfy (l "then") (l "if")),
			("prefix but not total", assertDoesNotSatisfy (l "i") (l "if")) ],
	PureTests "CharClass super" [
		("satisfies", c [cr 'a' 'b'] `assertSatisfies` l "a"),
		("does not satisfy", c [cr '0' '9'] `assertDoesNotSatisfy` l "a") ],
	PureTests "Space super" [
		("satisfies", patConcat [Space, l "test"] `assertSatisfies` l " test"),
		("err does not satisfy", patConcat [Space, l "test"] `assertDoesNotSatisfy` l "test") ],
	PureTests "disparate" [
		("Space", assertDoesNotSatisfy Space (l "if")) ]]]