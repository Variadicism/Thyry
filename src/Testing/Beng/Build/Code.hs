module Testing.Beng.Build.Code (
	testBuildCode
) where

import Utils.Errors
import Utils.Testing

import Testing.Beng.Utils.Mocks (a, b, mockABDivision)
import Testing.Beng.Utils.Ops ()

import Beng.Build (buildCodeUsing)
import Beng.Types.Ops (Op)

import Data.Text.Lazy (Text, unpack)

-- private

build :: Text -> Fallible [Op]
build mockCode = buildCodeUsing mockABDivision (unpack mockCode) mockCode

noBuild :: Text -> Fallible ()
noBuild mockCode = build mockCode `hasErrorElse` "Building should have failed!"

-- tests

testBuildCode :: TestCategory
testBuildCode = TestCategories "buildCode" [
	PureTests "nullary ops" [
		("one", do
			ops <- build "a"
			op <- assert1 "op" ops
			a.null op),
		("two", do
			ops <- build "ab"
			(op1, op2) <- assert2 "ops" ops
			a.null op1
			b.null op2)],
	PureTests "nonprefixed ops" [
		-- TODO
	],
	PureTests "skipping whitespace" [
		("leading", do
			ops <- build "\n  a"
			op <- assert1 "op" ops
			a.null op),
		("trailing", do
			ops <- build "b \t\t"
			op <- assert1 "op" ops
			b.null op),
		("infix", do
			ops <- build "a\n\t\tb"
			(aOp, bOp) <- assert2 "ops" ops
			a.null aOp
			b.null bOp)],
	PureTests "junk" [
		("err on immediately invalid code", do
			noBuild "ja"),
		("err on code that starts with an op, then has invalid junk", do
			noBuild "aj")],
	PureTests "blank" [
		("err on empty code", do
			noBuild ""),
		("err on whitespace-only code", do
			noBuild " \t ")]]