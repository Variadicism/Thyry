{-# LANGUAGE NoImplicitPrelude #-}

module Testing.Beng.Run.Ops (
	testRunOps
) where

import Utils.Collective
import Utils.Fallible hiding (Fallible)
import Utils.Populace (Populace(..))
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (dualton)
import Utils.Testing

import Testing.Beng.Utils.Mocks (aOp, aValue, addOp, appOp, bOp, bValue, divOp, expOp)
import Testing.Beng.Utils.Run (assertEval, assertUndefinedError)

import qualified Beng.Build.Context as Context
import Beng.Build.Context (PrecedenceBound(Default, None))
import Beng.Build.Context.Builders (l, argOfBuiltin, asInt, asInv, declare, define, intType, intValue)
import Beng.Operators.Definitions (Definition)
import Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as M
import Beng.Parse.Patterns (Argument(..))
import Beng.Run (run)
import Beng.Types.Locations (FileLocation(..), Location(..))
import Beng.Types.Invocations (Invocation(..), SomeInvocation(..))
import Beng.Types.Parse.Matches (SomeMatch(..))
import Beng.Types.Parse.Patterns (Delimited(..), Or(..), SomePattern(..))
import Beng.Things (
	SomeThing(..),
	NativeOptionalValue(..),
	NativeSomeValue(..) )
import Beng.Types.Things (
	SomeConcreteThing(..),
	SomeParameterizedThing,
	Thing(..),
	NativeBitsType(..),
	castThing )

import Data.Map ((!))

-- constants

argMatchOf :: Int -> String -> SomeParameterizedThing -> SomeInvocation -> SomeMatch
argMatchOf parentIndex name argType inv = SomeMatch $ M.Argument {
	pattern = Argument { argType, name, decLoc = BuiltinArg name parentIndex },
	matchedType = parameterize inv.returnType,
	parameterMatches = mempty,
	value = SomeThing inv }

runInv value = case asInv value of
	SomeInvocation invocation -> run invocation

someOrNone :: Definition
someOrNone = define Default
	[SomePattern $ Or $ dualton (l "none") $ argOfBuiltin 0 "Some" intType]
	intType
	(\args -> do
		let Just NativeOptionalValue{fal=maybeSome} = castThing $ args ! "Some"
		case maybeSome of
			Error _ -> return $ intValue 0
			Falue value -> runInv value)
	(Builtin 0)

sumCommas :: Definition
sumCommas = define Default
	[SomePattern Delimited { delimiter = l ",", delimitend = argOfBuiltin 1 "Element" intType }]
	intType
	(\args -> do
		let Just NativeSomeValue{valuesP=elements} = castThing $ args ! "Element"
		return $ intValue $ sum $
			assume $ sequence $ map (>>= asInt) $
			map runInv elements)
	(Builtin 1)

noneOp :: SomeInvocation
noneOp = SomeInvocation Invocation {
	operator = someOrNone,
	context = Context.empty,
	location = Builtin 2,
	returnType = SomeConcreteThing $ NativeBitsType 32,
	match = SomeMatch $ M.Or { matchIndex = 0,
		misses = [Argument "Some" intType (BuiltinArg "Some" 2)],
		match = SomeMatch $ M.Literal "none" }}

-- private

someOp :: SomeInvocation -> SomeInvocation
someOp inv = SomeInvocation Invocation {
	operator = someOrNone,
	context = Context.empty,
	location = Builtin 3,
	returnType = SomeConcreteThing $ NativeBitsType 32,
	match = SomeMatch $ M.Or {
		matchIndex = 1, misses = [],
		match = argMatchOf 3 "Some" intType inv }}

sumCommasOp :: SomeInvocation -> Populace SomeInvocation -> SomeInvocation
sumCommasOp firstArgInv invsTail = SomeInvocation Invocation {
	operator = sumCommas,
	context = Context.empty,
	location = Builtin 4,
	returnType = SomeConcreteThing $ NativeBitsType 32,
	match = SomeMatch $ M.Delimited {
		M.head = argMatchOf 4 "Element" intType firstArgInv,
		M.tail = toTail invsTail }}
	where
		toTail :: Populace SomeInvocation -> M.DelimitedTail
		toTail = M.DelimitedTailMatch . P.map
			((SomeMatch $ M.Literal ",",) . argMatchOf 4 "Element" intType)

-- tests

testRunOps :: TestCategory
testRunOps = TestCategories "evaluate" [
	PureTests "simple" [
		("nullary", do
			assertEval aValue aOp),
		("add", do
			assertEval (aValue + bValue) $ addOp aOp bOp),
		("divide additions", do
			assertEval ((aValue+aValue) `div` (bValue+aValue)) $ divOp (addOp aOp aOp) (addOp bOp aOp)),
		("4 deep", assertEval
			(bValue^(aValue `div` (aValue + aValue))) $
			expOp bOp $ divOp aOp $ addOp aOp $ appOp bOp aOp)],
	PureTests "Maybe" [
		("Just", do
			assertEval aValue $ someOp aOp),
		("Nothing", do
			assertEval 0 noneOp)],
	PureTests "List" [
		("Delimited", do
			assertEval (aValue + bValue*3) $ sumCommasOp aOp $ Populace bOp [bOp, bOp]) ],
	PureTests "undefined" [
		("declaration", do
			let location = Code $ FileLocation "undefined test" 1 1
			let declaration = declare None [l "test"] intType location
			let inv = SomeInvocation Invocation {
				operator = declaration,
				context = Context.empty,
				location,
				returnType = SomeConcreteThing $ NativeBitsType 32,
				match = SomeMatch $ M.Literal "test" }
			assertUndefinedError inv)]]
