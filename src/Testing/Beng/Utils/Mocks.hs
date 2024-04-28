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
	argOf,
	definitionOf,
	declarationOf,
	locationOf,
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
import Beng.Build.Context.Builders (l, s, asInt, argAt, asOp, buildContextFrom, define, defineRighty, defineLiteral, defineUsing, intType, intValue)
import qualified Beng.Build.Context.Builders as Builder
import Beng.Build.Types.Context (PrecedenceBound(..))
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Types.Matches (Match, value)
import Beng.Parse.Types.Patterns (Pattern(Argument, decLoc, name, argType))
import Beng.Ops.Types (Op(..))
import Beng.Ops.Types.Declarations (Associativity(..), Declaration)
import Beng.Ops.Types.Definitions (Definition(..))
import Beng.Types.Locations (Location(..))
import Beng.Run (run)
import Beng.Values.Types (Type(PreOpType), Value(..))

import Control.Composition ((.*))
import Data.Bits (complement)
import qualified Data.ByteString as BS
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

defineStaticNameValue :: Text -> Location -> Definition
defineStaticNameValue name location = do
	let (Builtin parentIndex) = location  -- All locations in mocks are Builtin-type.
	let a name argType = Argument { decLoc = BuiltinArg { name, parentIndex }, name, argType }
	defineUsing (Below $ declarationOf App) Righty
		[l name, s, l ":=", s, a "Value" intType, s, a "Scope" PreOpType]
		intType
		(\argName args location -> return case argName of
			"Scope" -> do
				let value = (args ! "Value").value
				[DefCard $ defineLiteral name intType value location]
			_ -> [])
		(\args -> run $ asOp $ args ! "Scope")
		location

defineLiteralInt :: Text -> Int -> (Location -> Definition)
defineLiteralInt text value =
	defineLiteral text intType $ BitsValue $ BS.pack [fromIntegral value]

hangingDefinitionOf :: ABCD -> Location -> Definition
hangingDefinitionOf enum location = case enum of
	A -> defineLiteralInt "a" aValue location
	B -> defineLiteralInt "b" bValue location
	Divide -> define Default
		[a "Dividend" intType, l "/", a "Divisor" intType]
		intType
		(\args -> do
			dividend <- asInt =<< (run $ asOp $ args ! "Dividend")
			divisor <- asInt =<< (run $ asOp $ args ! "Divisor")
			return $ intValue $ dividend `div` divisor)
		location
	DivideWords -> define (At $ declarationOf Divide)
		[a "Dividend" intType, s, l "and", s, a "Divisor" intType, s, l "divided"]
		intType
		(\args -> do
			dividend <- asInt =<< (run $ asOp $ args ! "Dividend")
			divisor <- asInt =<< (run $ asOp $ args ! "Divisor")
			return $ intValue $ dividend `div` divisor)
		location
	Exp -> define (Above $ declarationOf Divide)
		[a "Base" intType, l "^", a "Exponent" intType]
		intType
		(\args -> do
			base <- asInt =<< (run $ asOp $ args ! "Base")
			exponent <- asInt =<< (run $ asOp $ args ! "Exponent")
			return $ intValue $ base ^ exponent)
		location
	App ->
		{- `app` has the same precedence as `add` for testing purposes.
		   Sorry that that's inconsistent with Haskell where application has an extremely low precedence,
		   but there aren't many well-known righty operators and Haskell's builtin operators are
		   designed to never include two associativities in one precedence level. -}
		defineRighty (Below $ declarationOf Divide)
			[a "Left" intType, l "$", a "Right" intType]
			intType
			(run . asOp . (! "Left"))
			location
	AddWords -> define (At $ declarationOf App)
		[a "Augend" intType, s, l "and", s, a "Addend" intType, s, l "added"]
		intType
		(\args -> do
			augend <- asInt =<< (run $ asOp $ args ! "Augend")
			addend <- asInt =<< (run $ asOp $ args ! "Addend")
			return $ intValue $ augend + addend)
		location
	Add -> define (At $ declarationOf AddWords)
		[a "Augend" intType, l "+", a "Addend" intType]
		intType
		(\args -> do
			augend <- asInt =<< (run $ asOp $ args ! "Augend")
			addend <- asInt =<< (run $ asOp $ args ! "Addend")
			return $ intValue $ augend + addend)
		location
	Not -> define (Above $ declarationOf Divide)
		[l "!", a "Value" intType]  -- I couldn't come up with a cool name for this one.
		intType
		(\args -> do
			value <- asInt =<< (run $ asOp $ args ! "Value")
			return $ intValue (-value))
		location
	Negate -> define (Above $ declarationOf Not)
		[l "~", a "Negend" intType]  -- That's probably not a word. Too bad! It is now!
		intType
		(\args -> do
			negend <- asInt =<< (run $ asOp $ args ! "Negend")
			return $ intValue $ complement negend)
		location
	C -> defineStaticNameValue "C" location
	D -> defineStaticNameValue "D" location
	where
		a name argType = do
			let (Builtin parentIndex) = location  -- All these ops use Builtin location types.
			Argument { decLoc = BuiltinArg { name, parentIndex }, name, argType }


hangingABDivDefinitionOf :: ABDiv -> (Location -> Definition)
{- This is a painful assumption, but this actually works for abDiv as well since the enums
   respresent the same definitions in the same order plus more.
   But, if I don't make this assuption, then aOp and the other Op mocks will need a hanging
   definition maker passed as an argument, which will add tons of boilerplate. -}
hangingABDivDefinitionOf e = hangingDefinitionOf $ toEnum $ fromEnum e

argOf :: ABCD -> String -> Type -> Pattern
argOf abcd name argType = do
	let (Builtin locationIndex) = locationOf abcd
	argAt (BuiltinArg name locationIndex) name argType

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

prefixedUnaryOpMatch :: ABCD -> Text -> String -> Type -> Op -> Match
prefixedUnaryOpMatch abcd prefix argName argType op =
	Match.And $ dualton (Match.Literal prefix) (Match.Argument (locationOf abcd) argName argType $ OpValue op)

infixOpMatch :: ABCD -> String -> Type -> Text -> String -> Type -> Op -> Op -> Match
infixOpMatch abcd leftName leftType literal rightName rightType leftOp rightOp = Match.And $ P2.Populace2
	(Match.Argument (locationOf abcd) leftName leftType $ OpValue leftOp)
	(Match.Literal literal)
	[Match.Argument (locationOf abcd) rightName rightType $ OpValue rightOp]

type AssertOneArg = (Value -> Fallible ()) -> Op -> Fallible ()

type AssertTwoArgs = (Value -> Fallible ()) -> AssertOneArg

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
appMatch = infixOpMatch App "Left" intType "$" "Right" intType

expMatch :: (Op -> Op -> Match)
expMatch = infixOpMatch Exp "Base" intType "^" "Exponent" intType

divMatch :: (Op -> Op -> Match)
divMatch = infixOpMatch Divide "Dividend" intType "/" "Divisor" intType

addMatch :: (Op -> Op -> Match)
addMatch = infixOpMatch Add "Augend" intType "+" "Addend" intType

notMatch :: (Op -> Match)
notMatch = prefixedUnaryOpMatch Not "!" "Value" intType

negateMatch :: (Op -> Match)
negateMatch = prefixedUnaryOpMatch Negate "~" "Negend" intType

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