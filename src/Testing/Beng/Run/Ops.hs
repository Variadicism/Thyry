module Testing.Beng.Run.Ops (
	testRunOps
) where

import Utils.Fallible
import Utils.Testing

import Testing.Beng.Utils.Mocks (aOp, aValue, addOp, appOp, bOp, bValue, divOp, expOp)
import Testing.Beng.Utils.Run (assertEval, assertUndefinedError)

import Beng.Build.Context (PrecedenceBound(Default, None))
import Beng.Build.Context.Builders (a, l, asOp, declare, define)
import Beng.Build.Cards (Card(..))
import Beng.Ops (Op(..))
import Beng.Ops.Definitions (Definition)
import Beng.Parse.Matches (Capture(..), Match)
import qualified Beng.Parse.Matches as M
import Beng.Parse.Patterns (Pattern(..))
import Beng.Run.Ops (run)

import Data.List (singleton)
import Data.Map ((!))

-- constants

noneValue = 0

someOrNone :: Definition
someOrNone = define Default
	[Or [l "none", a "Some"]]
	\args -> do
		let (MaybeCapture maybeSome) = args ! "Some"
		case maybeSome of
			Nothing -> return noneValue
			Just capture -> run $ asOp capture

sumCommas :: Definition
sumCommas = define Default
	[Delimited (a "Element") (l ",")]
	\args -> do
		let (ListCapture elements) = args ! "Element"
		fmap sum $ reduceErrors $ map (run . asOp) elements

noneOp :: Op
noneOp = Op {
	card = DefCard someOrNone,
	match = M.Or { matchIndex = 0, misses = ["Some"], match = M.Literal "none" }}

-- private

someOp :: Op -> Op
someOp op = Op {
	card = DefCard someOrNone,
	match = M.And $ singleton $
		M.Or { matchIndex = 1, misses = [], match = M.Argument "Some" op }}

sumCommasOp :: Op -> [Op] -> Op
sumCommasOp firstArgOp argOpsTail = Op {
	card = DefCard sumCommas,
	match = M.And $ singleton $
		M.Delimited { M.head = M.Argument "Element" firstArgOp, M.tail = toTail argOpsTail }}
	where
		toTail :: ([Op] -> [(Match, Match)])
		toTail = map $ (M.Literal ",",) . M.Argument "Element"

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
			assertEval noneValue noneOp)],
	PureTests "List" [
		("Delimited", do
			assertEval (aValue + bValue*3) $ sumCommasOp aOp [bOp, bOp, bOp]) ],
	PureTests "undefined" [
		("declaration", do
			let declaration = declare None [l "test"]
			let op = Op { card = DecCard declaration, match = M.Literal "test" }
			assertUndefinedError op)]]