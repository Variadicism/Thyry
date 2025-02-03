module Testing.Beng.Build.Validate.PatternComparator (
	testPatternComparator
) where

import qualified Utils.Populace.Populace2 as P2
import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.And (testAnd)
import Testing.Beng.Build.Validate.PatternComparator.Arg (testArg)
import Testing.Beng.Build.Validate.PatternComparator.CharClass (testCharClass)
import Testing.Beng.Build.Validate.PatternComparator.Delimited (testDelimited)
import Testing.Beng.Build.Validate.PatternComparator.Literal (testLiteral)
import Testing.Beng.Build.Validate.PatternComparator.NamedText (testNamedText)
import Testing.Beng.Build.Validate.PatternComparator.Or (testOr)
import Testing.Beng.Build.Validate.PatternComparator.Space (testSpace)
import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (c, cr, l, multi, optional)
import Beng.Parse.Patterns (Pattern(..))
import Beng.Types.Locations (Location(Builtin))
import Beng.Values (thing)

-- private

a name argType = Argument { name, argType, decLoc = Builtin 0 }

testComparator :: TestCategory
testComparator = PureTests "interpattern complexities" do
	let capitalizedWords = And $ P2.dualton (c [cr 'A' 'Z']) (optional $ multi $ c [cr 'a' 'z'])
	let varDef = And $ P2.Populace2 capitalizedWords Space
		[l ":", l "=", Space, a "Value" thing]
	let varDefOrUn = And $ P2.Populace2 capitalizedWords Space
		[l ":", optional (l "/"), l "=", Space, a "Value" thing]
	[
		("complex equal", varDefOrUn `assertSatisfies` varDefOrUn),
		("complex proper super pattern is super", varDefOrUn `assertSatisfies` varDef),
		("complex proper super pattern is sub", varDef `assertDoesNotSatisfy` varDefOrUn) ]

-- tests

testPatternComparator :: TestCategory
testPatternComparator = TestCategories "pattern comparator" [
	testAnd,
	testArg,
	testCharClass,
	testDelimited,
	testLiteral,
	testNamedText,
	testOr,
	testSpace,
	testComparator ]