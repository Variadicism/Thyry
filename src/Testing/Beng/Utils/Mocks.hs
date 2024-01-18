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
	aMatch,
	bMatch,
	aOp,
	bOp,
	mockABDivision,
	mockABMath,
	mockABMathScopedCD,
	assertApp,
	assertExp,
	assertDiv,
	assertAdd,
	assertAddWords,
	assertDivWords,
	appMatch,
	expMatch,
	divMatch,
	addMatch,
	appOp,
	expOp,
	divOp,
	addOp
) where

import Prelude hiding ((<), (>), exp)

import Utils.Errors

import Testing.Beng.Utils.Ops ()

import Beng.Build.Cards (Card(..))
import qualified Beng.Build.Context as Context
import Beng.Build.Context.Builders ((=~), s, l, buildContext, define, defineRighty, defineLiteral, defineUsing)
import Beng.Build.Types.Context (PrecedenceBound(..))
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Types.Matches (Capture(..), Match)
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Declarations (Associativity(..))
import Beng.Types.Ops.Definitions (Definition(..))
import Beng.Run.Ops (evaluate)
import Beng.Run.Types.Values (Value(..), ValueType(..))

import Control.Composition ((.*))
import Data.Map ((!))
import qualified Data.Map as Map
import Data.Text.Lazy (Text, unpack)

-- constants

mockNothing = Context.empty

aValue :: Int
aValue = 3

bValue :: Int
bValue = 7

a :: Definition
a = defineLiteral "a" aValue

b :: Definition
b = defineLiteral "b" bValue

divide :: Definition
divide = define Default
	["Dividend" =~ DataType, l "/", "Divisor" =~ DataType]
	\args -> do
		let (DataValue dividend) = args ! "Dividend"
		let (DataValue divisor) = args ! "Divisor"
		return $ dividend `div` divisor

divideWords :: Definition
divideWords = define (At divide.declaration)
	["Dividend" =~ DataType, s, l "and", s, "Divisor" =~ DataType, s, l "divided"]
	\args -> do
		let (DataValue dividend) = args ! "Dividend"
		let (DataValue divisor) = args ! "Divisor"
		return $ dividend `div` divisor 

exp :: Definition
exp = define (Above divide.declaration)
	["Base" =~ DataType, l "^", "Exponent" =~ DataType]
	\args -> do
		let (DataValue base) = args ! "Base"
		let (DataValue exponent) = args ! "Exponent"
		return $ base ^ exponent

{- `app` has the same precedence as `add` for testing purposes.
   Sorry that that's inconsistent with Haskell where application has an extremely low precedence,
   but there aren't many well-known righty operators and Haskell's builtin operators are
   designed to never include two associativities in one precedence level. -}
app :: Definition
app = defineRighty (Below divide.declaration)
	["Left" =~ DataType, l "$", "Right" =~ DataType]
	(return . dataValue . (! "Left"))

addWords :: Definition
addWords = define (At app.declaration)
	["Augend" =~ DataType, s, l "and", s, "Addend" =~ DataType, s, l "added"]
	\args -> do
		let (DataValue augend) = args ! "Augend"
		let (DataValue addend) = args ! "Addend"
		return $ augend + addend

add :: Definition
add = define (At addWords.declaration)
	["Augend" =~ DataType, l "+", "Addend" =~ DataType]
	\args -> do
		let (DataValue augend) = args ! "Augend"
		let (DataValue addend) = args ! "Addend"
		return $ augend + addend

defineStaticNameValue :: Text -> Definition
defineStaticNameValue name =
	defineUsing (Below app.declaration) Righty
		[l name, s, l ":=", s, "Value" =~ DataType, s, "Scope" =~ PreOpType]
		(\args -> do
			-- TODO: Should I make a new type of Capture to cache argument results that were already run here?
			let (OpCapture valueOp) = args ! "Value"
			valueData <- evaluate valueOp
			let card = DefCard $ defineLiteral (unpack name) valueData
			return $ Map.singleton "Scope" [card])
		\args -> do
			let (OpValue scopeOp) = args ! "Scope"
			evaluate scopeOp

defineC :: Definition
defineC = defineStaticNameValue "C"

defineD :: Definition
defineD = defineStaticNameValue "D"

abDivisionDefs = [a, b, divide]

abMathDefs = abDivisionDefs ++ [divideWords, exp, app, addWords, add]

abMathScopedCDDefs = abMathDefs ++ [defineC, defineD]

mockABDivision = buildContext abDivisionDefs

mockABMath = buildContext abMathDefs

mockABMathScopedCD = buildContext abMathScopedCDDefs

aMatch :: Match
aMatch = Match.Literal "a"

bMatch :: Match
bMatch = Match.Literal "b"

aOp :: Op
aOp = Op (DefCard a) aMatch

bOp :: Op
bOp = Op (DefCard b) bMatch

-- private

type AssertTwoArgs = (Capture -> Fallible ()) -> (Capture -> Fallible ()) -> Op -> Fallible ()

infixOpMatch :: String -> Text -> String -> Op -> Op -> Match
infixOpMatch leftName literal rightName leftOp rightOp = Match.And [
	Match.Argument leftName DataType leftOp,
	Match.Literal literal,
	Match.Argument rightName DataType rightOp]

-- exported

assertApp :: AssertTwoArgs
assertApp assertLeft assertRight = app.args [("Left", assertLeft), ("Right", assertRight)]

assertExp :: AssertTwoArgs
assertExp assertBase assertExponent = exp.args [("Base", assertBase), ("Exponent", assertExponent)]

assertDiv :: AssertTwoArgs
assertDiv assertDividend assertDivisor = divide.args [("Dividend", assertDividend), ("Divisor", assertDivisor)]

assertAdd :: AssertTwoArgs
assertAdd assertAugend assertAddend = add.args [("Augend", assertAugend), ("Addend", assertAddend)]

assertAddWords :: AssertTwoArgs
assertAddWords assertAugend assertAddend = addWords.args [("Augend", assertAugend), ("Addend", assertAddend)]

assertDivWords :: AssertTwoArgs
assertDivWords assertDividend assertDivisor =
	divideWords.args [("Dividend", assertDividend), ("Divisor", assertDivisor)]

appMatch :: (Op -> Op -> Match)
appMatch = infixOpMatch "Left" "$" "Right"

expMatch :: (Op -> Op -> Match)
expMatch = infixOpMatch "Base" "^" "Exponent"

divMatch :: (Op -> Op -> Match)
divMatch = infixOpMatch "Dividend" "/" "Divisor"

addMatch :: (Op -> Op -> Match)
addMatch = infixOpMatch "Augend" "+" "Addend"

appOp :: (Op -> Op -> Op)
appOp = Op (DefCard app) .* appMatch

expOp :: (Op -> Op -> Op)
expOp = Op (DefCard exp) .* expMatch

divOp :: (Op -> Op -> Op)
divOp = Op (DefCard divide) .* divMatch

addOp :: (Op -> Op -> Op)
addOp = Op (DefCard add) .* addMatch