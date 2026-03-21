module Testing.Beng.Build.Validate.PatternComparator.And (
	testAnd
) where

import qualified Utils.Populace.Populace2 as P2
import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (l)
import Beng.Types.Parse.Patterns (And(..), SomePattern(..))

type Pattern = SomePattern

a :: [Pattern] -> Pattern
a = SomePattern . And . P2.assume

testAnd :: TestCategory
testAnd = PureTests "And" do
	let ifThen = a [l "if", l "then"]
	let ifThenElse = a [l "if", l "then", l "else"]
	[
		("exact", ifThen `assertSatisfies` ifThen),
		("err extra super", ifThenElse `assertDoesNotSatisfy` ifThen),
		("err extra sub", ifThen `assertDoesNotSatisfy` ifThenElse) ]
