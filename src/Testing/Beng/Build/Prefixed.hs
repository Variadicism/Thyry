module Testing.Beng.Build.Prefixed (
	testBuildPrefixed
) where

import Utils.Fallible
import Utils.Messaging (msg)
import qualified Utils.Populace as P
import Utils.Testing

import qualified Testing.Beng.Utils.Build as Test
import Testing.Beng.Utils.Mocks (a, assertNegate, assertNot, mockABCD)
import Testing.Beng.Utils.Ops ()
import Testing.Beng.Utils.Parsers (assertRest)

import Beng.Parse.Parsers.Code (Parse, target)
import Beng.Types.Invocations (SomeInvocation)

import Data.Text.Lazy (Text)

build :: Text -> Fallible [Parse SomeInvocation]
build mockCode =
	prependToError
		("An unexpected error occurred while building the mock code, " ++ show mockCode ++ "!") $
	mapError msg $
	fmap P.toList $
	Test.build mockABCD mockCode

-- tests

testBuildPrefixed :: TestCategory
testBuildPrefixed = TestCategories "build prefixed Op" [
	PureTests "nullary" [
		("one exactly", do
			result <- assert1 "result" =<< build "a"
			a.null result.target
			assertRest "" result),
		("one then junk", do
			result <- assert1 "result" =<< build "aj"
			a.null result.target
			assertRest "j" result),
		("junk then one", do
			build "ja" `hasErrorElse` "Beng built successfully prefixed with junk code!"),
		("empty", do
			build "" `hasErrorElse` "Beng built empty code successfully!")],
	PureTests "unary without suffix" [
		("one exactly", do
			result <- assert1 "result" =<< build "~a"
			assertNegate a.null.op result.target
			assertRest "" result),
		("one then junk", do
			result <- assert1 "result" =<< build "!al"
			assertNot a.null.op result.target
			assertRest "l" result),
		("one in another then junk", do
			result <- assert1 "result" =<< build "~!ah"
			assertNegate (assertNot.op a.null.op) result.target
			assertRest "h" result)]]
