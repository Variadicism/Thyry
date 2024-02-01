module Testing.Beng.Build.Prefixed (
	testBuildPrefixed
) where

import Utils.Fallible
import Utils.Messaging (msg)
import qualified Utils.Populace as P
import Utils.Testing

import qualified Testing.Beng.Utils.Build as Test
import Testing.Beng.Utils.Mocks (a, assertNegate, mockABCD)
import Testing.Beng.Utils.Ops ()
import Testing.Beng.Utils.Parsers (assertRest)

import Beng.Ops (Op)
import Beng.Parse.Parsers (Parse(..))

import Data.Text.Lazy (Text)

build :: Text -> Fallible [Parse Op]
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
			assertRest "" result)]]