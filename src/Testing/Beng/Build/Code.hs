module Testing.Beng.Build.Code (
	testBuildCode
) where

import Utils.Errors
import Utils.Testing

import Testing.Beng.Utils.Mocks (a, b, mockABDivision)
import Testing.Beng.Utils.Ops (assertOp)

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
testBuildCode = PureTests "buildCode" [
	("read one nullary op from all code", do
		ops <- build "a"
		op <- assert1 "op" ops
		assertOp a [] op),
	("read two nullary ops from all code", do
		ops <- build "ab"
		(op1, op2) <- assert2 "ops" ops
		assertOp a [] op1
		assertOp b [] op2),
	("err on empty code", do
		noBuild ""),
	("err on whitespace-only code", do
		noBuild " \t "),
	("err on immediately invalid code", do
		noBuild "ja"),
	("err on code that starts with an op, then has invalid junk", do
		noBuild "aj")]