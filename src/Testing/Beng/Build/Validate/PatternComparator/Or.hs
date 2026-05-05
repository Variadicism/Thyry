module Testing.Beng.Build.Validate.PatternComparator.Or (
	testOr
) where

import qualified Utils.Populace.Populace2 as P2
import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (c, cr, e, patConcat)
import Beng.Types.Parse.Patterns (Or(..), SomePattern(..), Space(..))

-- private

type Pattern = SomePattern

o :: [Pattern] -> Pattern
o = SomePattern . Or . P2.assume

zero = c [cr '0' '0']

two = c [cr '2' '2']

low = c [cr '1' '2']

digit = c [cr '0' '9']

-- tests

testOr :: TestCategory
testOr = TestCategories "Or candidate" [
	TestCategories "Or requirement" [
		PureTests "satisfies" [
			("exact", o [zero, two] `assertSatisfies` o [zero, two]),
			("one subpattern candidate", o [zero, low] `assertSatisfies` o [zero, two]),
			("all subpatterns candidates", o [digit, low] `assertSatisfies` o [zero, two]),
			("exact reversed", o [zero, two] `assertSatisfies` o [two, zero]),
			("one subpattern candidate reversed", o [zero, low] `assertSatisfies` o [two, zero]),
			("all subpattern candidates reversed", o [digit, low] `assertSatisfies` o [two, zero]) ],
		PureTests "does not satisfy" [
			("all requirement subpatterns candidates", o [zero, two] `assertDoesNotSatisfy` o [low, digit]),
			("one requirement subpattern candidate", o [zero, two] `assertDoesNotSatisfy` o [zero, digit]),
			("one subpattern disparate", o [zero, SomePattern Space] `assertDoesNotSatisfy` o [zero, digit]) ]],
	TestCategories "end of requirement" [
		-- I cannot pass an empty requirement into `satisfies`, so each requirement and candidate share a prefix.
		-- This means that the second requirement subpattern, the Or, will match against [] on the second pass.
		PureTests "satisfies" [
			("one optional", patConcat [zero, o [e, zero]] `assertSatisfies` zero),
			("all optional", patConcat [zero, o [e, e]] `assertSatisfies` zero) ],
		PureTests "does not satisfy" [
			("none optional", patConcat [zero, o [zero, two]] `assertDoesNotSatisfy` zero)]],
	TestCategories "disparate" [
		PureTests "satisfies" [
			("requirement in one", digit `assertSatisfies` o [zero, two]) ],
		PureTests "does not satisfy" [
			("misses one", low `assertDoesNotSatisfy` o [zero, two]),
			("misses all", zero `assertDoesNotSatisfy` o [low, two]) ]]]
