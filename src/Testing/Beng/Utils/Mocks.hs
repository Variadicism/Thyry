module Testing.Beng.Utils.Mocks (
	ABCD(..),
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
	not,
	negate,
	aMatch,
	bMatch,
	aOp,
	bOp,
	mockABDivision,
	mockABCD,
	appMatch,
	expMatch,
	divMatch,
	addMatch,
	notMatch,
	negateMatch,
	appOp,
	expOp,
	divOp,
	addOp,
	notOp,
	negateOp,
	definitionOf,
	declarationOf,
	cardOf,
	assertApp,
	assertExp,
	assertDiv,
	assertAdd,
	assertAddWords,
	assertDivWords,
	assertNot,
	assertNegate
) where

import Prelude hiding (exp, negate, not)

import Utils.Fallible
import Utils.Populace.Populace2 (dualton)
import qualified Utils.Populace.Populace2 as P2

import Testing.Beng.Utils.Ops ()

import Beng.Build.Cards (Card(..))
import qualified Beng.Build.Context as Context
import Beng.Build.Context.Builders (l, s, asOp, buildContextFrom, define, defineRighty, defineLiteral, defineLiteralData, defineUsing)
import qualified Beng.Build.Context.Builders as Builder
import Beng.Build.Types.Context (PrecedenceBound(..))
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Types.Matches (Capture, Match)
import Beng.Parse.Types.Patterns (Pattern(Argument))
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Declarations (Associativity(..), Declaration)
import Beng.Types.Ops.Definitions (Definition(..))
import Beng.Types.Locations (Location(..))
import Beng.Run.Ops (run)

import Control.Composition ((.*))
import Data.Bits (complement)
import Data.Map ((!))
import Data.Text.Lazy (Text)

-- simple constants

aValue :: Int
aValue = 3

bValue :: Int
bValue = 7

-- types

data ABDiv = ABDivA | ABDivB | ABDivDivide deriving (Show, Eq, Enum)

data ABCD = A | B | Divide |
	DivideWords | Exp | App | AddWords | Add | Not | Negate |
	C | D
	deriving (Show, Eq, Enum)

-- private

arg = Argument

defineStaticNameValue :: Text -> (Location -> Definition)
defineStaticNameValue name =
	defineUsing (Below $ declarationOf App) Righty
		[l name, s, l ":=", s, arg "Value", s, arg "Scope"]
		(\argName args location -> return case argName of
			"Scope" -> do
				let valueOp = asOp $ args ! "Value"
				[DefCard $ defineLiteral name valueOp location]
			_ -> [])
		\args -> run $ asOp $ args ! "Scope"

hangingDefinitionOf :: (ABCD -> Location -> Definition)
hangingDefinitionOf = \case
	A -> defineLiteralData "a" aValue
	B -> defineLiteralData "b" bValue
	Divide -> define Default
		[arg "Dividend", l "/", arg "Divisor"]
		\args -> do
			dividend <- run $ asOp $ args ! "Dividend"
			divisor <- run $ asOp $ args ! "Divisor"
			return $ dividend `div` divisor
	DivideWords -> define (At $ declarationOf Divide)
		[arg "Dividend", s, l "and", s, arg "Divisor", s, l "divided"]
		\args -> do
			dividend <- run $ asOp $ args ! "Dividend"
			divisor <- run $ asOp $ args ! "Divisor"
			return $ dividend `div` divisor
	Exp -> define (Above $ declarationOf Divide)
		[arg "Base", l "^", arg "Exponent"]
		\args -> do
			base <- run $ asOp $ args ! "Base"
			exponent <- run $ asOp $ args ! "Exponent"
			return $ base ^ exponent
	App ->
		{- `app` has the same precedence as `add` for testing purposes.
		   Sorry that that's inconsistent with Haskell where application has an extremely low precedence,
		   but there aren't many well-known righty operators and Haskell's builtin operators are
		   designed to never include two associativities in one precedence level. -}
		defineRighty (Below $ declarationOf Divide)
			[arg "Left", l "$", arg "Right"]
			(run . asOp . (! "Left"))
	AddWords -> define (At $ declarationOf App)
		[arg "Augend", s, l "and", s, arg "Addend", s, l "added"]
		\args -> do
			augend <- run $ asOp $ args ! "Augend"
			addend <- run $ asOp $ args ! "Addend"
			return $ augend + addend
	Add -> define (At $ declarationOf AddWords)
		[arg "Augend", l "+", arg "Addend"]
		\args -> do
			augend <- run $ asOp $ args ! "Augend"
			addend <- run $ asOp $ args ! "Addend"
			return $ augend + addend
	Not -> define (Above $ declarationOf Divide)
		[l "!", arg "Value"]  -- I couldn't come up with a cool name for this one.
		\args -> do
			value <- run $ asOp $ args ! "Value"
			return (-value)
	Negate -> define (Above $ declarationOf Not)
		[l "~", arg "Negend"]  -- That's probably not a word. Too bad! It is now!
		\args -> do
			negend <- run $ asOp $ args ! "Negend"
			return $ complement negend
	C -> defineStaticNameValue "C"
	D -> defineStaticNameValue "D"

hangingABDivDefinitionOf :: ABDiv -> (Location -> Definition)
{- This is a painful assumption, but this actually works for abDiv as well since the enums
   respresent the same definitions in the same order plus more.
   But, if I don't make this assuption, then aOp and the other Op mocks will need a hanging
   definition maker passed as an argument, which will add tons of boilerplate. -}
hangingABDivDefinitionOf e = hangingDefinitionOf $ toEnum $ fromEnum e

definitionOf :: (ABCD -> Definition)
definitionOf = Builder.definitionOf hangingDefinitionOf

declarationOf :: (ABCD -> Declaration)
declarationOf = Builder.declarationOf hangingDefinitionOf

cardOf :: (ABCD -> Card)
cardOf = DefCard . definitionOf

locationOf :: (ABCD -> Location)
locationOf = Builtin . fromEnum

opOf :: ABCD -> (Match -> Op)
opOf a = Op (cardOf a) (locationOf a)

prefixedUnaryOpMatch :: Text -> String -> Op -> Match
prefixedUnaryOpMatch prefix argName op =
	Match.And $ dualton (Match.Literal prefix) (Match.Argument argName op)

infixOpMatch :: String -> Text -> String -> Op -> Op -> Match
infixOpMatch leftName literal rightName leftOp rightOp = Match.And $ P2.Populace2
	(Match.Argument leftName leftOp)
	(Match.Literal literal)
	[Match.Argument rightName rightOp]

type AssertOneArg = (Capture -> Fallible ()) -> Op -> Fallible ()

type AssertTwoArgs = (Capture -> Fallible ()) -> AssertOneArg

-- exported
---- contexts

mockNothing = Context.empty

mockABDivision = buildContextFrom hangingABDivDefinitionOf ABDivA

mockABCD = buildContextFrom hangingDefinitionOf A

---- definitions

a = definitionOf A

b = definitionOf B

app = definitionOf App

exp = definitionOf Exp

divide = definitionOf Divide

add = definitionOf Add

divideWords = definitionOf DivideWords

addWords = definitionOf AddWords

not = definitionOf Not

negate = definitionOf Negate

---- matches

aMatch :: Match
aMatch = Match.Literal "a"

bMatch :: Match
bMatch = Match.Literal "b"

appMatch :: (Op -> Op -> Match)
appMatch = infixOpMatch "Left" "$" "Right"

expMatch :: (Op -> Op -> Match)
expMatch = infixOpMatch "Base" "^" "Exponent"

divMatch :: (Op -> Op -> Match)
divMatch = infixOpMatch "Dividend" "/" "Divisor"

addMatch :: (Op -> Op -> Match)
addMatch = infixOpMatch "Augend" "+" "Addend"

notMatch :: (Op -> Match)
notMatch = prefixedUnaryOpMatch "!" "Value"

negateMatch :: (Op -> Match)
negateMatch = prefixedUnaryOpMatch "~" "Negend"

---- ops

aOp :: Op
aOp = opOf A aMatch

bOp :: Op
bOp = opOf B bMatch

appOp :: (Op -> Op -> Op)
appOp = opOf App .* appMatch

expOp :: (Op -> Op -> Op)
expOp = opOf Exp .* expMatch

divOp :: (Op -> Op -> Op)
divOp = opOf Divide .* divMatch

addOp :: (Op -> Op -> Op)
addOp = opOf Add .* addMatch

notOp :: (Op -> Op)
notOp = opOf Not . notMatch

negateOp :: (Op -> Op)
negateOp = opOf Negate . negateMatch

---- assertions

assertApp :: AssertTwoArgs
assertApp assertLeft assertRight = app.args
	[("Left", assertLeft), ("Right", assertRight)]

assertExp :: AssertTwoArgs
assertExp assertBase assertExponent = exp.args
	[("Base", assertBase), ("Exponent", assertExponent)]

assertDiv :: AssertTwoArgs
assertDiv assertDividend assertDivisor = divide.args
	[("Dividend", assertDividend), ("Divisor", assertDivisor)]

assertAdd :: AssertTwoArgs
assertAdd assertAugend assertAddend = add.args
	[("Augend", assertAugend), ("Addend", assertAddend)]

assertAddWords :: AssertTwoArgs
assertAddWords assertAugend assertAddend = addWords.args
	[("Augend", assertAugend), ("Addend", assertAddend)]

assertDivWords :: AssertTwoArgs
assertDivWords assertDividend assertDivisor = divideWords.args
	[("Dividend", assertDividend), ("Divisor", assertDivisor)]

assertNot :: AssertOneArg
assertNot assertValue = not.args [("Value", assertValue)]

assertNegate :: AssertOneArg
assertNegate assertNegend = negate.args [("Negend", assertNegend)]