module Testing.Beng.Build.Validate.PatternComparator.CharClass (
	testCharClass
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (c, cr, l)
import Beng.Types.Parse.Patterns (Pattern(..))

testCharClass :: TestCategory
testCharClass = TestCategories "CharClass sub" do
	let ints = c [cr '0' '9']
	let letters = c [cr 'a' 'z', cr 'A' 'Z']
	let alphaNum = c [cr '0' '9', cr 'a' 'z', cr 'A' 'Z']
	let splitInts = c [cr '0' '2', cr '3' '9']
	let words = c [cr 'a' 'z', cr 'A' 'Z', cr ' ' ' ', cr '-' '-']
	[
		TestCategories "CharClass super" [
			PureTests "satisfies" [
				("exact", ints `assertSatisfies` ints),
				("super split but equal", splitInts `assertSatisfies` ints),
				("sub split but equal", ints `assertSatisfies` splitInts),
				("super superset", alphaNum `assertSatisfies` ints) ],
			PureTests "does not satisfy" [
				("disparate", ints `assertDoesNotSatisfy` letters),
				("sub superset", ints `assertDoesNotSatisfy` alphaNum) ]],
		PureTests "Literal super" [
			("satisfies", ints `assertSatisfies` l "0"),
			("err does not satisfy", ints `assertDoesNotSatisfy` l "f") ],
		PureTests "Space super" [
			("satisfies", Space `assertSatisfies` words),
			("err does not satisfy", Space `assertDoesNotSatisfy` alphaNum) ],
		PureTests "disparate" [
			("Delimited", ints `assertDoesNotSatisfy` Delimited (l "P") (l ",")) ]]