module Beng.Build.Context.Builders (
	argAt,
	argOfBuiltin,
	c,
	nc,
	cr,
	cr2,
	e,
	s,
	l,
	by,
	textAt,
	noContext,
	multi,
	optional,
	patConcat,
	bitType,
	intType,
	asInv,
	asInvOf,
	asNativeString,
	asBits,
	bitsValue,
	asInt,
	bitValue,
	intValue,
	stringType,
	stringValue,
	declare,
	declareLiteral,
	define,
	defineRighty,
	defineUsing,
	defineLiteral,
	definitionOf,
	declarationOf,
	buildContextFrom
) where

import Utils.Fallible (FallibleI(..))

import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2

import Beng.Build.Context (Context(..), push)
import qualified Beng.Build.Context as Context
import Beng.Types.Invocations (SomeInvocation)
import Beng.Operators.Declarations (ArgContextBuilder, Associativity(..), Declaration(..), PrecedenceBound(..))
import Beng.Operators.Definitions (Definition(..), Runner)
import qualified Beng.Operators.Definitions as Definition
import Beng.Parse.Patterns.And ()
import Beng.Parse.Patterns.Arg ()
import Beng.Parse.Patterns.CharClass ()
import Beng.Parse.Patterns.Delimited ()
import Beng.Parse.Patterns.Literal ()
import Beng.Parse.Patterns.NamedText ()
import Beng.Parse.Patterns.Or ()
import Beng.Parse.Patterns.Space ()
import Beng.Types.Parse.Patterns (And(..), ArgP(..), Argument(..), CharClass(..), CharRange(..), Delimited(..), Literal(..), NamedText(..), Or(..), SomePattern(..), Space(..))
import Beng.Run (run)
import Beng.Errors (Fallible)
import Beng.Types.Things (
	SomeThing(..),
	NativeBitsValue(..),
	NativeStringValue(..),
	NativeBitsType(..),
	NativeStringType(..),
	castThing )
import Beng.Types.Locations (Location(..))

import Control.Composition ((.*))
import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Int (Int32)
import Data.Text.Lazy (Text)

-- exported

argAt :: Location -> String -> SomeThing -> SomePattern
argAt decLoc name argType = SomePattern $ ArgP Argument { name, argType, decLoc }

argOfBuiltin :: Int -> String -> SomeThing -> SomePattern
argOfBuiltin builtinIndex name argType =
	SomePattern $ ArgP Argument { name, argType, decLoc = BuiltinArg name builtinIndex }

c :: [CharRange] -> SomePattern
c ranges = SomePattern $ CharClass { ranges = P.assume ranges, negate = False }

nc :: [CharRange] -> SomePattern
nc ranges = SomePattern $ CharClass { ranges = P.assume ranges, negate = True }

cr :: Char -> Char -> CharRange
cr = CharRange

cr2 :: Char -> CharRange
cr2 c = CharRange c c

e :: SomePattern
e = SomePattern $ Literal ""

s :: SomePattern
s = SomePattern Space

l :: Text -> SomePattern
l = SomePattern . Literal

by :: SomePattern -> SomePattern -> SomePattern
by delimitend delimiter = SomePattern $ Delimited { delimitend, delimiter }

textAt :: Location -> String -> SomePattern -> SomePattern
textAt decLoc name subpattern = SomePattern $ NamedText { name, subpattern, decLoc }

noContext :: ArgContextBuilder
noContext _ _ _ = Falue []

multi :: SomePattern -> SomePattern
multi = SomePattern . Delimited e

optional :: SomePattern -> SomePattern
optional = SomePattern . Or . P2.dualton e

patConcat :: [SomePattern] -> SomePattern
patConcat = \case
	[] -> e
	[solo] -> solo
	(first:(second:rest)) -> SomePattern $ And $ P2.Populace2 first second rest

bitType = SomeThing $ NativeBitsType 1

-- TODO: replace with an "integer" type operator that returns the type.
intType = SomeThing $ NativeBitsType 32

bitsValue :: Int -> [Int] -> SomeThing
bitsValue size byteValues =
	SomeThing $ NativeBitsValue { size, bytes = BS.pack $ map (fromInteger . toInteger) byteValues }

bitValue :: Bool -> SomeThing
bitValue true = bitsValue 1 [if true then 1 else 0]

intValue :: Int32 -> SomeThing
intValue int = bitsValue 32 $
	map ((.&. 0xFF) . shiftR (fromInteger $ toInteger int)) [24, 16, 8, 0]

stringType = SomeThing NativeStringType  -- TODO: replace with language-level string type when available

stringValue = SomeThing . NativeStringValue

asInv :: (SomeThing -> SomeInvocation)
asInv value = case castThing value of
	Just op -> op
	Nothing -> error $
		"A builtin invocation assumed that an arg was returning an InvValue, " ++
		"but it actually captured a(n) " ++ show value ++ "!"

asInvOf :: String -> (SomeThing -> Fallible a) -> SomeThing -> Fallible a
asInvOf expectedDesc get value = case castThing value of
	Just op -> run op >>= get
	Nothing -> error $ "A(n) " ++ expectedDesc ++
		" or invocation of such was expected, but instead, it's a(n) " ++ show value ++ "!"

asNativeString :: SomeThing -> Fallible Text
asNativeString value = case castThing value of
	Just NativeStringValue{text} -> return text
	Nothing -> asInvOf "native string" asNativeString value

asBits :: Int -> (SomeThing -> Fallible ByteString)
asBits size value = case castThing value of
	Just bitsValue@(NativeBitsValue{bytes=bytestring}) ->
		if BS.length bytestring == ceiling (fromIntegral size / 8.0) then
			return bytestring
		-- TODO: replace `error` with `TypeError`
		else error $ show size ++ "b was expected, but " ++
			show (BS.length bytestring) ++ "B (" ++ show (BS.length bytestring * 8) ++
			"b) were found instead: " ++ show bitsValue
	Nothing -> asInvOf (show size ++ "b") (asBits size) value

asInt :: SomeThing -> Fallible Int32
asInt value = do  -- TODO TEMPORARY
	bytestring <- asBits 32 value
	let [b1, b2, b3, b4] = BS.unpack bytestring
	return $
		(shiftL (fromIntegral b1) 24) .|.
		(shiftL (fromIntegral b2) 16) .|.
		(shiftL (fromIntegral b3) 8) .|.
		(fromIntegral b4)

declare :: PrecedenceBound -> [SomePattern] -> SomeThing -> Location -> Declaration
declare precedence subpatterns returnType location =
	Declaration { precedence, location, returnType,
		pattern = patConcat subpatterns,
		associativity = Lefty, contextualize = noContext }

declareLiteral :: Text -> SomeThing -> Location -> Declaration
declareLiteral literal returnType location = Declaration {
	location,
	pattern = SomePattern $ Literal literal,
	returnType,
	associativity = Lefty {- irrelevant in nullary ops -},
	contextualize = noContext,
	precedence = None }

defineUsing ::
	PrecedenceBound -> Associativity ->
	[SomePattern] -> SomeThing -> ArgContextBuilder -> Runner -> Location -> Definition
defineUsing precedence associativity subpatterns returnType contextualize runWith location =
	Definition { location, runWith,
		declaration = Declaration {
			precedence, location, contextualize, associativity, returnType,
			pattern = patConcat subpatterns }}

define :: PrecedenceBound -> [SomePattern] -> SomeThing -> (Runner -> Location -> Definition)
define precedence subpatterns returnType =
	defineUsing precedence Lefty subpatterns returnType noContext

defineRighty :: PrecedenceBound -> [SomePattern] -> SomeThing -> (Runner -> Location -> Definition)
defineRighty precedence subpatterns returnType = defineUsing precedence Righty subpatterns returnType noContext

defineLiteral :: Text -> SomeThing -> SomeThing -> Location -> Definition
defineLiteral literal valueType value location = Definition {
	runWith = const $ Falue value,
	location,
	declaration = declareLiteral literal valueType location }

definitionOf :: Enum e => (e -> Location -> Definition) -> e -> Definition
definitionOf hangingDefinitionOf e = hangingDefinitionOf e $ Builtin $ fromEnum e

declarationOf :: Enum e => ((e -> Location -> Definition) -> e -> Declaration)
declarationOf = Definition.declaration .* definitionOf

buildContextFrom :: Enum e => (e -> Location -> Definition) -> (e -> Context)
buildContextFrom hangingDefinitionOf =
	foldl (flip push) Context.empty .
		map (definitionOf hangingDefinitionOf) . enumFrom
