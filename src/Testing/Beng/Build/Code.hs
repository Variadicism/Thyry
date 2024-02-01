module Testing.Beng.Build.Code (
	testBuildCode
) where

import Utils.Fallible
import qualified Utils.Populace as P
import Utils.Testing

import Testing.Beng.Utils.Mocks (a, b, assertDiv, mockABDivision)
import Testing.Beng.Utils.Ops ()

import Beng.Build (buildCodeUsing)
import Beng.Types.Ops (Op)

import Data.Text.Lazy (Text, unpack)

-- private

build :: Text -> Fallible [Op]
build mockCode = fmap P.toList $ buildCodeUsing mockABDivision (unpack mockCode) mockCode

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
			ops <- build "a b"
			(op1, op2) <- assert2 "ops" ops
			a.null op1
			b.null op2),
		("err two smushed", do
			build "ab" `hasErrorElse` "Ops should require a Space separator!")],
	PureTests "nonprefixed ops" [
		("one division", do
			ops <- build "a/b"
			op <- assert1 "op" ops
			assertDiv a.null.op b.null.op op),
		("two divisions", do
			ops <- build "a/b\nb/b"
			(ab, bb) <- assert2 "ops" ops
			assertDiv a.null.op b.null.op ab
			assertDiv b.null.op b.null.op bb),
		("one chained division", do
			ops <- build "a/b/b"
			op <- assert1 "op" ops
			assertDiv (assertDiv.op a.null.op b.null.op) b.null.op op),
		("nullaries wrapping a division", do
			ops <- build "b b/a\n\t\ta"
			(bOp, divBA, aOp) <- assert3 "ops" ops
			b.null bOp
			assertDiv b.null.op a.null.op divBA
			a.null aOp),
		("err division with junk", do
			build "a/k" `hasErrorElse` "This division should not have been parsed correctly!")],
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