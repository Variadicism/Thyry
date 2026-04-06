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

import Beng.Build.Context.Builders (c, cr, l, multi, optional, s, textAt)
import Beng.Types.Locations (Location(Builtin))
import Beng.Types.Parse.Patterns (And(..), Argument(..), SomePattern(..))
import Beng.Things (thing)

-- private

testComparator :: TestCategory
testComparator = PureTests "interpattern complexities" do
	let capitalizedWords = SomePattern $ And $ P2.dualton (c [cr 'A' 'Z']) (optional $ multi $ c [cr 'a' 'z'])
	let valueArg = SomePattern Argument { name = "Thing", argType = thing, decLoc = Builtin 0 }

	let varDef = SomePattern $ And $ P2.Populace2 capitalizedWords s
		[l ":", l "=", s, valueArg]
	let varDefOrUn = SomePattern $ And $ P2.Populace2 capitalizedWords s
		[l ":", optional (l "/"), l "=", s, valueArg]
	let varUndef = SomePattern $ And $ P2.Populace2 capitalizedWords s
		[l ":/=", s, valueArg]
	let namedCapitalizedWords = textAt (Builtin 1) "Name" capitalizedWords
	let varNamedDef = SomePattern $ And $ P2.Populace2 namedCapitalizedWords s
		[l ":", l "=", s, valueArg]
	let varNamedDefOrUn = SomePattern $ And $ P2.Populace2 namedCapitalizedWords s
		[l ":", optional (l "/"), l "=", s, valueArg]
	[
		("equal", varDefOrUn `assertSatisfies` varDefOrUn),
		("proper super pattern is super", varDefOrUn `assertSatisfies` varDef),
		("proper super pattern is sub", varDef `assertDoesNotSatisfy` varDefOrUn),
		("NamedText ignored in super", varNamedDefOrUn `assertSatisfies` varDef),
		("NamedText matched in super and sub", varNamedDefOrUn `assertSatisfies` varNamedDef),
		("Or can match partially", varDefOrUn `assertSatisfies` varUndef) ]

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
