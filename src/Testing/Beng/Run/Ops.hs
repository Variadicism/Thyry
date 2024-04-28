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

import Beng.Build.Context (PrecedenceBound(Default, None))
import Beng.Build.Context.Builders (l, argOfBuiltin, asInt, asOp, declare, define, intType, intValue)
import Beng.Build.Cards (Card(..))
import Beng.Ops (Op(..))
import Beng.Ops.Definitions (Definition)
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Matches as M
import Beng.Parse.Patterns (Parameter(..), Pattern(..))
import Beng.Run (run)
import Beng.Types.Locations (FileLocation(..), Location(..))
import Beng.Values.Types (Type, Value(NativeOptionalValue, NativeSomeValue, OpValue))

import Data.Map ((!))

-- constants

argMatchOf :: Int -> String -> Type -> Value -> Match
argMatchOf parentIndex name argType argValue = M.Argument {
	argType, name, argValue,
	decLoc = BuiltinArg name parentIndex }

someOrNone :: Definition
someOrNone = define Default
	[Or $ dualton (l "none") $ argOfBuiltin 0 "Some" intType]
	intType
	(\args -> do
		let (NativeOptionalValue maybeSome) = args ! "Some"
		case maybeSome of
			Error _ -> return $ intValue 0
			Falue value -> run $ asOp value)
	(Builtin 0)

sumCommas :: Definition
sumCommas = define Default
	[Delimited (l ",") $ argOfBuiltin 1 "Element" intType]
	intType
	(\args -> do
		let (NativeSomeValue elements) = args ! "Element"
		return $ intValue $ sum $
			assume $ sequence $ map (>>= asInt) $
			map (run . asOp) elements)
	(Builtin 1)

noneOp :: Op
noneOp = Op {
	card = DefCard someOrNone,
	location = Builtin 2,
	match = M.Or { matchIndex = 0,
		misses = [Parameter "Some" intType (BuiltinArg "Some" 2)],
		match = M.Literal "none" }}

-- private

someOp :: Op -> Op
someOp op = Op {
	card = DefCard someOrNone,
	location = Builtin 3,
	match = M.Or {
		matchIndex = 1, misses = [],
		match = argMatchOf 3 "Some" intType $ OpValue op }}

sumCommasOp :: Op -> Populace Op -> Op
sumCommasOp firstArgOp argOpsTail = Op {
	card = DefCard sumCommas,
	location = Builtin 4,
	match = M.Delimited {
		M.head = argMatchOf 4 "Element" intType $ OpValue firstArgOp,
		M.tail = toTail argOpsTail }}
	where
		toTail :: (Populace Op -> M.DelimitedTail)
		toTail = M.DelimitedTailMatch . P.map
			((M.Literal ",",) . argMatchOf 4 "Element" intType . OpValue)

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
			let op = Op { card = DecCard declaration, location, match = M.Literal "test" }
			assertUndefinedError op)]]