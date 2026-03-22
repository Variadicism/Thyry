module Testing.Beng.Build.Validate.PatternComparator.Literal (
	testLiteral
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (c, cr, e, l, optional, patConcat)
import Beng.Types.Parse.Patterns (SomePattern(..), Space(..))

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
		("satisfies", patConcat [SomePattern Space, l "test"] `assertSatisfies` l " test"),
		("err does not satisfy", patConcat [SomePattern Space, l "test"] `assertDoesNotSatisfy` l "test") ],
	PureTests "optional super sequence" [
		("skips optional middle", patConcat [l "a", optional (l "b"), l "c"] `assertSatisfies` l "ac"),
		("matches optional middle", patConcat [l "a", optional (l "b"), l "c"] `assertSatisfies` l "abc") ],
	PureTests "direct optional super sequence" [
		-- TODO: The test below SHOULD FAIL!! We found this in a refactor, but it's a preexisting issue. Fix!
		("Space middle", patConcat [l "a", SomePattern Space, l "c"] `assertSatisfies` l "ac"),
		("empty Literal middle", patConcat [l "a", e, l "c"] `assertSatisfies` l "ac") ],
	PureTests "disparate" [
		("Space", assertDoesNotSatisfy (SomePattern Space) (l "if")) ]]]
