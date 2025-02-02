module Testing.Beng.Build.Validate.PatternComparator.Space (
	testSpace
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (l, patConcat)
import Beng.Types.Parse.Patterns (Pattern(Space))

testSpace :: TestCategory
testSpace = PureTests "Space sub" [
	("Space super", Space `assertSatisfies` Space),
	("end of super", patConcat [l "a", l "b"] `assertSatisfies` patConcat [l "a", l "b", Space]),
	("err disparate", l "y" `assertDoesNotSatisfy` Space) ]