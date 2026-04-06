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
	operatorOf,
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

import qualified Beng.Build.Context as Context
import Beng.Build.Context.Builders (l, s, asInt, argAt, asNativeString, asInv, bitType, bitValue, buildContextFrom, define, defineRighty, defineLiteral, defineUsing, intType, intValue, stringType, stringValue)
import qualified Beng.Build.Context.Builders as Builder
import Beng.Types.Build.Context (PrecedenceBound(..))
import Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Matches (SomeMatch(..), value)
import Beng.Types.Parse.Patterns (ArgP(..), Argument(..), SomePattern(..))
import Beng.Types.Operators (SomeOperator(..))
import Beng.Types.Invocations (Invocation(..), SomeInvocation(..))
import Beng.Types.Operators.Declarations (Associativity(..), Declaration)
import Beng.Types.Operators.Definitions (Definition(..))
import Beng.Types.Locations (Location(..))
import Beng.Run (run)
import Beng.Types.Things (
	SomeThing(..),
	PreOpType(..) )

import Control.Composition ((.*))
import Data.Bits (complement)
import Data.Map ((!))
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

-- simple constants

aValue :: Int
aValue = 3

bValue :: Int
bValue = 7

-- types

data ABDiv = ABDivA | ABDivB | ABDivDivide deriving (Show, Eq, Enum)

data ABCD = A | B | Divide |
	DivideWords | Exp | App | AddWords | Add | Not | Negate |
	C | D |
	Name | Initial | StartsWith | Concat
	deriving (Show, Eq, Enum)

-- private

type Pattern = SomePattern
type Op = SomeInvocation
type Operator = SomeOperator

defineStaticNameValue :: Text -> Location -> Definition
defineStaticNameValue name location = do
	let (Builtin parentIndex) = location  -- All locations in mocks are Builtin-type.
	let a name argType = SomePattern $ ArgP Argument {
		decLoc = BuiltinArg { name, parentIndex }, name, argType }
	defineUsing (Below $ SomeOperator $ declarationOf App) Righty
		[l name, s, l ":=", s, a "Thing" intType, s, a "Scope" (SomeThing $ PreOpType intType)]
		intType
		(\argName args location -> return case argName of
			"Scope" -> do
				let value = (args ! "Thing").value
				[SomeOperator $ defineLiteral name intType value location]
			_ -> [])
		(\args -> run $ asInv $ args ! "Scope")
		location

defineLiteralInt :: Text -> Int -> (Location -> Definition)
defineLiteralInt text value =
	defineLiteral text intType $ intValue $ fromIntegral value

hangingDefinitionOf :: ABCD -> Location -> Definition
hangingDefinitionOf enum location = case enum of
	A -> defineLiteralInt "a" aValue location
	B -> defineLiteralInt "b" bValue location
	Divide -> define Default
		[a "Dividend" intType, l "/", a "Divisor" intType]
		intType
		(\args -> do
			dividend <- asInt =<< (run $ asInv $ args ! "Dividend")
			divisor <- asInt =<< (run $ asInv $ args ! "Divisor")
			return $ intValue $ dividend `div` divisor)
		location
	DivideWords -> define (At $ SomeOperator $ declarationOf Divide)
		[a "Dividend" intType, s, l "and", s, a "Divisor" intType, s, l "divided"]
		intType
		(\args -> do
			dividend <- asInt =<< (run $ asInv $ args ! "Dividend")
			divisor <- asInt =<< (run $ asInv $ args ! "Divisor")
			return $ intValue $ dividend `div` divisor)
		location
	Exp -> define (Above $ SomeOperator $ declarationOf Divide)
		[a "Base" intType, l "^", a "Exponent" intType]
		intType
		(\args -> do
			base <- asInt =<< (run $ asInv $ args ! "Base")
			exponent <- asInt =<< (run $ asInv $ args ! "Exponent")
			return $ intValue $ base ^ exponent)
		location
	App ->
		{- `app` has the same precedence as `add` for testing purposes.
		   Sorry that that's inconsistent with Haskell where application has a very low precedence,
		   but there aren't many well-known righty operators and Haskell's builtin operators are
		   designed to never include two associativities in one precedence level. -}
		defineRighty (Below $ SomeOperator $ declarationOf Divide)
			[a "Left" intType, l "$", a "Right" intType]
			intType
			(run . asInv . (! "Left"))
			location
	AddWords -> define (At $ SomeOperator $ declarationOf App)
		[a "Augend" intType, s, l "and", s, a "Addend" intType, s, l "added"]
		intType
		(\args -> do
			augend <- asInt =<< (run $ asInv $ args ! "Augend")
			addend <- asInt =<< (run $ asInv $ args ! "Addend")
			return $ intValue $ augend + addend)
		location
	Add -> define (At $ SomeOperator $ declarationOf AddWords)
		[a "Augend" intType, l "+", a "Addend" intType]
		intType
		(\args -> do
			augend <- asInt =<< (run $ asInv $ args ! "Augend")
			addend <- asInt =<< (run $ asInv $ args ! "Addend")
			return $ intValue $ augend + addend)
		location
	Not -> define (Above $ SomeOperator $ declarationOf Divide)
		[l "!", a "Thing" intType]  -- I couldn't come up with a cool name for this one.
		intType
		(\args -> do
			value <- asInt =<< (run $ asInv $ args ! "Thing")
			return $ intValue (-value))
		location
	Negate -> define (Above $ SomeOperator $ declarationOf Not)
		[l "~", a "Negend" intType]  -- That's probably not a word. Too bad! It is now!
		intType
		(\args -> do
			negend <- asInt =<< (run $ asInv $ args ! "Negend")
			return $ intValue $ complement negend)
		location
	C -> defineStaticNameValue "C" location
	D -> defineStaticNameValue "D" location
	Name -> define None
		[l "Name"]
		stringType
		(\_ -> return $ stringValue "Keith Moon")
		location
	Initial -> define None
		[l "Initial"]
		stringType
		(\_ -> return $ stringValue "K")
		location
	StartsWith -> define (Below $ SomeOperator $ declarationOf Add)
		[a "Target" stringType, s, l "starts", s, l "with", s, a "Prefix" stringType]
		bitType
		(\args -> do
			target <- asNativeString =<< (run $ asInv $ args ! "Target")
			prefix <- asNativeString =<< (run $ asInv $ args ! "Prefix")
			return $ bitValue $ prefix `Text.isPrefixOf` target)
		location
	Concat -> define (At $ SomeOperator $ declarationOf Add)
		[a "Prefix" stringType, s, l "+", s, a "Suffix" stringType]
		stringType
		(\args -> do
			prefix <- asNativeString =<< (run $ asInv $ args ! "Prefix")
			suffix <- asNativeString =<< (run $ asInv $ args ! "Suffix")
			return $ stringValue $ Text.concat [prefix, suffix])
		location
	where
		a name argType = do
			let (Builtin parentIndex) = location  -- All these ops use Builtin location types.
			SomePattern $ ArgP Argument { decLoc = BuiltinArg { name, parentIndex }, name, argType }


hangingABDivDefinitionOf :: ABDiv -> (Location -> Definition)
{- This is a painful assumption, but this actually works for abDiv as well since the enums
   respresent the same definitions in the same order plus more.
   But, if I don't make this assuption, then aOp and the other Op mocks will need a hanging
   definition maker passed as an argument, which will add tons of boilerplate. -}
hangingABDivDefinitionOf e = hangingDefinitionOf $ toEnum $ fromEnum e

argOf :: ABCD -> String -> SomeThing -> Pattern
argOf abcd name argType = do
	let (Builtin locationIndex) = locationOf abcd
	argAt (BuiltinArg name locationIndex) name argType

definitionOf :: (ABCD -> Definition)
definitionOf = Builder.definitionOf hangingDefinitionOf

declarationOf :: (ABCD -> Declaration)
declarationOf = Builder.declarationOf hangingDefinitionOf

operatorOf :: (ABCD -> Operator)
operatorOf = SomeOperator . definitionOf

locationOf :: (ABCD -> Location)
locationOf = Builtin . fromEnum

opOf :: ABCD -> (SomeMatch -> Op)
opOf a = \match -> SomeInvocation Invocation {
	operator = definitionOf a,
	context = mockABCD,
	location = locationOf a,
	match }

prefixedUnaryOpMatch :: ABCD -> Text -> String -> SomeThing -> Op -> SomeMatch
prefixedUnaryOpMatch abcd prefix argName argType op =
	SomeMatch $ Match.And $ dualton (SomeMatch $ Match.Literal prefix) $ SomeMatch $ Match.Argument {
		decLoc = (locationOf abcd), name = argName, argType, value = SomeThing op }

infixOpMatch :: ABCD -> String -> SomeThing -> Text -> String -> SomeThing -> Op -> Op -> SomeMatch
infixOpMatch abcd leftName leftType literal rightName rightType leftOp rightOp =
	SomeMatch $ Match.And $ P2.Populace2
		(SomeMatch $ Match.Argument (locationOf abcd) leftName leftType $ SomeThing leftOp)
		(SomeMatch $ Match.Literal literal)
		[SomeMatch $ Match.Argument (locationOf abcd) rightName rightType $ SomeThing rightOp]

type AssertOneArg = (SomeThing -> Fallible ()) -> Op -> Fallible ()

type AssertTwoArgs = (SomeThing -> Fallible ()) -> AssertOneArg

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

aMatch :: SomeMatch
aMatch = SomeMatch $ Match.Literal "a"

bMatch :: SomeMatch
bMatch = SomeMatch $ Match.Literal "b"

appMatch :: (Op -> Op -> SomeMatch)
appMatch = infixOpMatch App "Left" intType "$" "Right" intType

expMatch :: (Op -> Op -> SomeMatch)
expMatch = infixOpMatch Exp "Base" intType "^" "Exponent" intType

divMatch :: (Op -> Op -> SomeMatch)
divMatch = infixOpMatch Divide "Dividend" intType "/" "Divisor" intType

addMatch :: (Op -> Op -> SomeMatch)
addMatch = infixOpMatch Add "Augend" intType "+" "Addend" intType

notMatch :: (Op -> SomeMatch)
notMatch = prefixedUnaryOpMatch Not "!" "Thing" intType

negateMatch :: (Op -> SomeMatch)
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
assertNot assertValue = not.args [("Thing", assertValue)]

assertNegate :: AssertOneArg
assertNegate assertNegend = negate.args [("Negend", assertNegend)]
