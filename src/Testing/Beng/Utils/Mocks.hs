module Testing.Beng.Utils.Mocks (
	mockNothing,
	aValue,
	bValue,
	a,
	b,
	exp,
	divideWords,
	divide,
	addWords,
	add,
	mockABDivision,
	mockABAddDivExp,
	assertExpArgs,
	assertExpArgsEq,
	assertDivideWordsArgs,
	assertDivideWordsArgsEq,
	assertDivideArgs,
	assertDivideArgsEq,
	assertAddWordsArgs,
	assertAddWordsArgsEq,
	assertAddArgs,
	assertAddArgsEq
) where

import Prelude hiding ((<), (>), exp)

import Utils.Errors

import Testing.Beng.Utils.Ops (assertArgsEq, assertOp)

import Beng.Build.Context.Builders ((=~), s, l, define, defineLiteral)
import Beng.Build.Types.Context (Context(..))
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Definitions (Definition)
import Beng.Run.Types.Values (Value(..), ValueType(..))

import Data.Map ((!))
import qualified Data.Set as Set

-- constants

mockNothing = Context {
	precedence = [],
	definitions = [] }

aValue :: Int
aValue = 3

bValue :: Int
bValue = 7

a :: Definition
a = defineLiteral "a" $ IntValue aValue

b :: Definition
b = defineLiteral "b" $ IntValue bValue

exp :: Definition
exp = define
	["Base" =~ IntType, l "^", "Exponent" =~ IntType]
	\args -> do
		let (IntValue base) = args ! "Base"
		let (IntValue exponent) = args ! "Exponent"
		IntValue $ base ^ exponent

divideWords :: Definition
divideWords = define
	["Dividend" =~ IntType, s, l "and", s, "Divisor" =~ IntType, s, l "divided"]
	\args -> do
		let (IntValue dividend) = args ! "Dividend"
		let (IntValue divisor) = args ! "Divisor"
		IntValue $ dividend `div` divisor 

divide :: Definition
divide = define
	["Dividend" =~ IntType, l "/", "Divisor" =~ IntType]
	\args -> do
		let (IntValue dividend) = args ! "Dividend"
		let (IntValue divisor) = args ! "Divisor"
		IntValue $ dividend `div` divisor 

addWords :: Definition
addWords = define
	["Augend" =~ IntType, s, l "and", s, "Addend" =~ IntType, s, l "added"]
	\args -> do
		let (IntValue augend) = args ! "Augend"
		let (IntValue addend) = args ! "Addend"
		IntValue $ augend + addend

add = define
	["Augend" =~ IntType, l "+", "Addend" =~ IntType]
	\args -> do
		let (IntValue augend) = args ! "Augend"
		let (IntValue addend) = args ! "Addend"
		IntValue $ augend + addend

mockABDivision = Context {
	precedence = [Set.singleton 0],
	definitions = [a, b, divide] }

mockABAddDivExp = Context {
	precedence = [Set.fromList [0, 1], Set.fromList [2, 3], Set.singleton 4],
	definitions = [a, b, exp, divideWords, divide, addWords, add] }

-- exported

assertExpArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertExpArgs assertBase assertExponent =
	assertOp exp [("Base", assertBase), ("Exponent", assertExponent)]

assertExpArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertExpArgsEq baseDef exponentDef =
	assertArgsEq exp [("Base", baseDef), ("Exponent", exponentDef)]

assertDivideWordsArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertDivideWordsArgs assertDividend assertDivisor =
	assertOp divideWords [("Dividend", assertDividend), ("Divisor", assertDivisor)]

assertDivideWordsArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertDivideWordsArgsEq dividendDef divisorDef =
	assertArgsEq divideWords [("Dividend", dividendDef), ("Divisor", divisorDef)]

assertDivideArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertDivideArgs assertDividend assertDivisor =
	assertOp divide [("Dividend", assertDividend), ("Divisor", assertDivisor)]

assertDivideArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertDivideArgsEq dividendDef divisorDef =
	assertArgsEq divide [("Dividend", dividendDef), ("Divisor", divisorDef)]

assertAddWordsArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertAddWordsArgs assertAugend assertAddend =
	assertOp addWords [("Augend", assertAugend), ("Addend", assertAddend)]

assertAddWordsArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertAddWordsArgsEq augendDef addendDef =
	assertArgsEq addWords [("Augend", augendDef), ("Addend", addendDef)]

assertAddArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertAddArgs assertAugend assertAddend =
	assertOp add [("Augend", assertAugend), ("Addend", assertAddend)]

assertAddArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertAddArgsEq augendDef addendDef =
	assertArgsEq add [("Augend", augendDef), ("Addend", addendDef)]