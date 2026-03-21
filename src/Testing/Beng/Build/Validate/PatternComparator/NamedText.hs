module Testing.Beng.Build.Validate.PatternComparator.NamedText (
	testNamedText
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (c, cr)
import Beng.Types.Locations (Location(Builtin))
import Beng.Types.Parse.Patterns (NamedText(..), SomePattern(..), Space(..))

-- private

type Pattern = SomePattern

nt :: String -> Pattern -> Pattern
nt name subpattern = SomePattern $ NamedText { name, subpattern, decLoc = Builtin 1 }

zero = c [cr '0' '0']

digit = c [cr '0' '9']

-- tests

testNamedText :: TestCategory
testNamedText = TestCategories "NamedText sub" [
	TestCategories "NamedText super" [
		PureTests "satisfies" [
			("exact", nt "Zero" zero `assertSatisfies` nt "Zero" zero),
			("sub subpattern", nt "Zero" digit `assertSatisfies` nt "Zero" zero) ],
		PureTests "does not satisfy" [
			("misnamed", nt "Number" zero `assertDoesNotSatisfy` nt "Zero" zero),
			("super subpattern", nt "Zero" zero `assertDoesNotSatisfy` nt "Zero" digit),
			("disparate subpattern", nt "Zero" (SomePattern Space) `assertDoesNotSatisfy` nt "Zero" zero) ]],
	TestCategories "disparate super" [
		PureTests "satisfies" [
			("unnamed exact subpattern", zero `assertSatisfies` nt "Zero" zero),
			("unnamed super subpattern", digit `assertSatisfies` nt "Zero" zero) ],
		PureTests "does not satisfy" [
			("unnamed sub subpattern", zero `assertDoesNotSatisfy` nt "Number" digit),
			("Space", SomePattern Space `assertDoesNotSatisfy` nt "Zero" zero) ]]]
