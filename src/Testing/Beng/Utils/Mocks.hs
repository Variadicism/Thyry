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

import Utils.Fallible

import Testing.Beng.Utils.Ops ()

import Beng.Build.Cards (Card(..))
import qualified Beng.Build.Context as Context
import Beng.Build.Context.Builders (s, l, asOp, buildContext, define, defineRighty, defineLiteral, defineLiteralData, defineUsing)
import Beng.Build.Types.Context (PrecedenceBound(..))
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Types.Matches (Capture(..), Match)
import Beng.Parse.Types.Patterns (Pattern(Argument))
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Declarations (Associativity(..))
import Beng.Types.Ops.Definitions (Definition(..))
import Beng.Run.Ops (run)

import Control.Composition ((.*))
import Data.Map ((!))
import Data.Text.Lazy (Text, pack)

-- constants

mockNothing = Context.empty

aValue :: Int
aValue = 3

bValue :: Int
bValue = 7

a :: Definition
a = defineLiteralData "a" aValue

b :: Definition
b = defineLiteralData "b" bValue

divide :: Definition
divide = define Default
	[arg "Dividend", l "/", arg "Divisor"]
	\args -> do
		dividend <- run $ asOp $ args ! "Dividend"
		divisor <- run $ asOp $ args ! "Divisor"
		return $ dividend `div` divisor

divideWords :: Definition
divideWords = define (At divide.declaration)
	[arg "Dividend", s, l "and", s, arg "Divisor", s, l "divided"]
	\args -> do
		dividend <- run $ asOp $ args ! "Dividend"
		divisor <- run $ asOp $ args ! "Divisor"
		return $ dividend `div` divisor 

exp :: Definition
exp = define (Above divide.declaration)
	[arg "Base", l "^", arg "Exponent"]
	\args -> do
		base <- run $ asOp $ args ! "Base"
		exponent <- run $ asOp $ args ! "Exponent"
		return $ base ^ exponent

{- `app` has the same precedence as `add` for testing purposes.
   Sorry that that's inconsistent with Haskell where application has an extremely low precedence,
   but there aren't many well-known righty operators and Haskell's builtin operators are
   designed to never include two associativities in one precedence level. -}
app :: Definition
app = defineRighty (Below divide.declaration)
	[arg "Left", l "$", arg "Right"]
	(run . asOp . (! "Left"))

addWords :: Definition
addWords = define (At app.declaration)
	[arg "Augend", s, l "and", s, arg "Addend", s, l "added"]
	\args -> do
		augend <- run $ asOp $ args ! "Augend"
		addend <- run $ asOp $ args ! "Addend"
		return $ augend + addend

add :: Definition
add = define (At addWords.declaration)
	[arg "Augend", l "+", arg "Addend"]
	\args -> do
		augend <- run $ asOp $ args ! "Augend"
		addend <- run $ asOp $ args ! "Addend"
		return $ augend + addend

defineStaticNameValue :: String -> Definition
defineStaticNameValue name =
	defineUsing (Below app.declaration) Righty
		[l (pack name), s, l ":=", s, arg "Value", s, arg "Scope"]
		(\argName args -> return case argName of
			"Scope" -> do
				let valueOp = asOp $ args ! "Value"
				[DefCard $ defineLiteral name valueOp]
			_ -> [])
		\args -> run $ asOp $ args ! "Scope"

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

arg :: String -> Pattern
arg = Argument

type AssertTwoArgs = (Capture -> Fallible ()) -> (Capture -> Fallible ()) -> Op -> Fallible ()

infixOpMatch :: String -> Text -> String -> Op -> Op -> Match
infixOpMatch leftName literal rightName leftOp rightOp = Match.And [
	Match.Argument leftName leftOp,
	Match.Literal literal,
	Match.Argument rightName rightOp]

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