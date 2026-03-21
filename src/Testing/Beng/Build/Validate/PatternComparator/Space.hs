module Testing.Beng.Build.Validate.PatternComparator.Space (
	testSpace
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (l, patConcat)
import Beng.Types.Parse.Patterns (SomePattern(..), Space(..))

testSpace :: TestCategory
testSpace = PureTests "Space sub" [
	("Space super", SomePattern Space `assertSatisfies` SomePattern Space),
	("end of super", patConcat [l "a", l "b"] `assertSatisfies` patConcat [l "a", l "b", SomePattern Space]),
	("err disparate", l "y" `assertDoesNotSatisfy` SomePattern Space) ]
