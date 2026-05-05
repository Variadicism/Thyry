module Testing.Beng.Build.Code (
	testBuildCode
) where

import Utils.Fallible
import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2
import Utils.Testing

import Testing.Beng.Utils.Mocks (a, b, assertDiv, mockABCD)
import Testing.Beng.Utils.Ops ()

import Beng.Build (buildCodeUsing)
import qualified Beng.Build.Context as Context
import Beng.Build.Context.Builders (
	argOfBuiltin,
	define,
	defineLiteral,
	intType,
	intValue,
	l,
	s,
	stringType,
	stringValue )
import Beng.Types.Build.Context (PrecedenceBound(..))
import Beng.Types.Invocations (Invocation(..), SomeInvocation(..))
import Beng.Types.Locations (Location(..))
import Beng.Types.Operators (SomeOperator(..))
import Beng.Types.Things (
	CombinedThings(..),
	NativeBitsType(..),
	NativeStringType(..),
	NativeType(..),
	Parameter(..),
	PreOpType(..),
	SomeConcreteThing(..),
	SomeParameterizedThing(..),
	SomeThing(..) )

import Control.Monad (void)
import Data.Text.Lazy (Text, unpack)

-- private

build :: Text -> Fallible [SomeInvocation]
build mockCode = fmap P.toList $ buildCodeUsing mockABCD (unpack mockCode) mockCode

buildUsing :: Context.Context -> Text -> Fallible [SomeInvocation]
buildUsing context mockCode = fmap P.toList $ buildCodeUsing context (unpack mockCode) mockCode

noBuild :: Text -> Fallible ()
noBuild mockCode = build mockCode `hasErrorElse` "Building should have failed!"

paramContext :: Context.Context
paramContext = do
	let thingType = SomeParameterizedThing $ NativeType $ const []
	let valueType = SomeParameterizedThing $ Parameter {
			decLoc = BuiltinArg { name = "Value", parentIndex = 50 },
			name = "Value",
			baseType = thingType }
	let rightValueType = SomeParameterizedThing $ Parameter {
			decLoc = BuiltinArg { name = "Right", parentIndex = 52 },
			name = "Right",
			baseType = thingType }
	let identity = define None
			[l "id", s, argOfBuiltin 50 "Value" valueType]
			valueType
			(\_ -> return $ SomeThing $ NativeStringType)
			(Builtin 50)
	let tagged = define Default
			[argOfBuiltin 51 "Value" valueType, s, l "tagged"]
			valueType
			(\_ -> return $ SomeThing $ NativeStringType)
			(Builtin 51)
	let either = define Default
			[argOfBuiltin 52 "Value" valueType, s, l "or", s,
				argOfBuiltin 52 "Right" rightValueType]
			(SomeParameterizedThing $ CombinedThings $
				P2.dualton valueType rightValueType)
			(\_ -> return $ SomeThing $ NativeStringType)
			(Builtin 52)
	let scope = SomeParameterizedThing $ PreOpType valueType
	let capture = define None
			[l "capture", s, argOfBuiltin 53 "Scope" scope]
			valueType
			(\_ -> return $ SomeThing $ NativeStringType)
			(Builtin 53)
	let literalName = defineLiteral "Name" stringType (stringValue "Name") (Builtin 54)
	let literalA = defineLiteral "a" intType (intValue 3) (Builtin 55)
	Context.fromOps $ map SomeOperator [
		identity,
		tagged,
		either,
		capture,
		literalName,
		literalA ]

assertReturnType :: SomeInvocation -> SomeConcreteThing -> Fallible ()
assertReturnType (SomeInvocation invocation) expected =
	(invocation.returnType, expected) `isEqualElse`
		"Invocation return type was not resolved as expected!"

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
	PureTests "parameterized invocation returns" [
		("prefix argument resolves return parameter", do
			op <- assert1 "op" =<< buildUsing paramContext "id Name"
			op `assertReturnType` SomeConcreteThing NativeStringType),
		("non-prefixed argument resolves return parameter", do
			op <- assert1 "op" =<< buildUsing paramContext "Name tagged"
			op `assertReturnType` SomeConcreteThing NativeStringType),
		("two parameters resolve combined return type", do
			op <- assert1 "op" =<< buildUsing paramContext "Name or a"
			op `assertReturnType` SomeConcreteThing (CombinedThings $
				P2.dualton
					(SomeConcreteThing NativeStringType)
					(SomeConcreteThing $ NativeBitsType 32))),
		("preop argument resolves return parameter", do
			op <- assert1 "op" =<< buildUsing paramContext "capture id Name"
			op `assertReturnType` SomeConcreteThing NativeStringType)],
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
	TestCategories "type checks" [
		PureTests "satisfies" [
			("simple int division", void do
				build "a/b"),
			("int addition distinct from string concatenation", void do
				build "a+b"),
			("string starts with", void do
				build "Name starts with Initial")],
		PureTests "does not satisfy" [
			-- TODO: assert type errors specifically when the parser returns better error structures.
			("string minus int",
				noBuild "Name - b"),
			("type mismatch in preop",
				noBuild "C := a\nInitial - a")]],
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
