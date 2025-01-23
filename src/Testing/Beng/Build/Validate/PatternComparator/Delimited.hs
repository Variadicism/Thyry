module Testing.Beng.Build.Validate.PatternComparator.Delimited (
	testDelimited
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Build.Context.Builders (c, cr)
import Beng.Types.Parse.Patterns (Pattern(Delimited, Space))

-- private

d = Delimited

testDelimited :: TestCategory
testDelimited = TestCategories "Delimited" do
	let digit = c [cr '0' '9']
	let alphaNum = c [cr '0' '9', cr 'a' 'z', cr 'A' 'Z']
	let comma = c [cr ',' ',']
	let punct = c [cr '!' '/']
	[
		PureTests "satisfies" [
			("exact", d digit comma `assertSatisfies` d digit comma),
			("super delimitend", d alphaNum comma `assertSatisfies` d digit comma),
			("super delimiter", d digit punct `assertSatisfies` d digit comma),
			("super both", d alphaNum punct `assertSatisfies` d digit comma) ],
		PureTests "does not satisfy" [
			("sub", d digit comma `assertDoesNotSatisfy` d alphaNum punct),
			("disparate delimitend", d Space punct `assertDoesNotSatisfy` d alphaNum punct),
			("disparate delimiter", d alphaNum Space `assertDoesNotSatisfy` d alphaNum punct),
			("disparate", Space `assertDoesNotSatisfy` d alphaNum punct) ]]