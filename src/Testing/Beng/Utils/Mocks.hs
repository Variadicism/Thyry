module Testing.Beng.Utils.Mocks (
	mockNothing,
	aValue,
	bValue,
	a,
	b,
	app,
	exp,
	divideWords,
	divide,
	addWords,
	add,
	mockABDivision,
	mockABAddDivExpApp,
	assertAppArgs,
	assertAppArgsEq,
	assertExpArgs,
	assertExpArgsEq,
	assertDivWordsArgs,
	assertDivWordsArgsEq,
	assertDivArgs,
	assertDivArgsEq,
	assertAddWordsArgs,
	assertAddWordsArgsEq,
	assertAddArgs,
	assertAddArgsEq
) where

import Prelude hiding ((<), (>), exp)

import Utils.Errors

import Testing.Beng.Utils.Ops (assertArgsEq, assertOp)

import qualified Beng.Build.Context as Context
import Beng.Build.Context.Builders ((=~), s, l, buildContext, define, defineRighty, defineLiteral)
import Beng.Build.Types.Context (PrecedenceBound(..))
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Definitions (Definition(..))
import Beng.Run.Types.Values (Value(..), ValueType(..))

import Data.Map ((!))

-- constants

mockNothing = Context.empty

aValue :: Int
aValue = 3

bValue :: Int
bValue = 7

a :: Definition
a = defineLiteral "a" $ IntValue aValue

b :: Definition
b = defineLiteral "b" $ IntValue bValue

divide :: Definition
divide = define Default
	["Dividend" =~ IntType, l "/", "Divisor" =~ IntType]
	\args -> do
		let (IntValue dividend) = args ! "Dividend"
		let (IntValue divisor) = args ! "Divisor"
		return $ IntValue $ dividend `div` divisor

divideWords :: Definition
divideWords = define (At divide.declaration)
	["Dividend" =~ IntType, s, l "and", s, "Divisor" =~ IntType, s, l "divided"]
	\args -> do
		let (IntValue dividend) = args ! "Dividend"
		let (IntValue divisor) = args ! "Divisor"
		return $ IntValue $ dividend `div` divisor 

exp :: Definition
exp = define (Above divide.declaration)
	["Base" =~ IntType, l "^", "Exponent" =~ IntType]
	\args -> do
		let (IntValue base) = args ! "Base"
		let (IntValue exponent) = args ! "Exponent"
		return $ IntValue $ base ^ exponent

{- `app` has the same precedence as `add` for testing purposes.
   Sorry that that's inconsistent with Haskell where application has an extremely low precedence,
   but there aren't many well-known righty operators and Haskell's builtin operators are
   designed to never include two associativities in one precedence level. -}
app :: Definition
app = defineRighty (Below divide.declaration)
	["Left" =~ IntType, l "$", "Right" =~ IntType]
	(return . (! "Left"))

addWords :: Definition
addWords = define (At app.declaration)
	["Augend" =~ IntType, s, l "and", s, "Addend" =~ IntType, s, l "added"]
	\args -> do
		let (IntValue augend) = args ! "Augend"
		let (IntValue addend) = args ! "Addend"
		return $ IntValue $ augend + addend

add = define (At addWords.declaration)
	["Augend" =~ IntType, l "+", "Addend" =~ IntType]
	\args -> do
		let (IntValue augend) = args ! "Augend"
		let (IntValue addend) = args ! "Addend"
		return $ IntValue $ augend + addend

mockABDivision = buildContext [a, b, divide]

mockABAddDivExpApp = buildContext [a, b, divide, divideWords, exp, app, addWords, add]

-- exported

assertAppArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertAppArgs assertLeft assertRight =
	assertOp app [("Left", assertLeft), ("Right", assertRight)]

assertAppArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertAppArgsEq leftDef rightDef =
	assertArgsEq app [("Left", leftDef), ("Right", rightDef)]

assertExpArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertExpArgs assertBase assertExponent =
	assertOp exp [("Base", assertBase), ("Exponent", assertExponent)]

assertExpArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertExpArgsEq baseDef exponentDef =
	assertArgsEq exp [("Base", baseDef), ("Exponent", exponentDef)]

assertDivWordsArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertDivWordsArgs assertDivnd assertDivisor =
	assertOp divideWords [("Dividend", assertDivnd), ("Divisor", assertDivisor)]

assertDivWordsArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertDivWordsArgsEq dividendDef divisorDef =
	assertArgsEq divideWords [("Dividend", dividendDef), ("Divisor", divisorDef)]

assertDivArgs :: (Op -> Fallible ()) -> (Op -> Fallible ()) -> (Op -> Fallible ())
assertDivArgs assertDivnd assertDivisor =
	assertOp divide [("Dividend", assertDivnd), ("Divisor", assertDivisor)]

assertDivArgsEq :: Definition -> Definition -> (Op -> Fallible ())
assertDivArgsEq dividendDef divisorDef =
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