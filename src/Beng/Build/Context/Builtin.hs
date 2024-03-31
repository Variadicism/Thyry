module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import qualified Utils.Populace.Populace2 as P2

import Beng.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Build.Context.Builders (c, cr, e, s, l, multi, argAt, asOp, buildContextFrom, declarationOf, define, defineUsing, defineLiteral, definitionOf, textAt)
import Beng.Build.Types.Cards (Card(DefCard))
import Beng.Parse.Types.Matches (value)
import Beng.Parse.Types.Patterns (Pattern(..))
import Beng.Run (run)
import Beng.Ops.Types.Declarations (Associativity(..), Declaration)
import Beng.Ops.Types.Definitions (Definition(..))
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (Location(..))
import Beng.Values.Types (Type(..), Value(..))

import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import qualified Data.ByteString as BS
import Data.Int (Int32)
import Data.Map ((!))
import qualified Data.Map as Map
import Data.Text.Lazy (Text, unpack)
import GHC.Records (HasField, getField)

-- constants

valueName :: Pattern
valueName = do
	let uppercaseLetter = c [cr 'A' 'Z']
	let letter = c [cr 'A' 'Z', cr 'a' 'z']
	let capitalizedWord = And $ P2.dualton uppercaseLetter (Or $ P2.dualton e $ multi letter)
	Delimited { delimiter = Space, delimitend = capitalizedWord }

-- types

-- TODO: replace with an "integer" type operator that returns the type.
intType = BitsType 32

-- private

assertValue :: (Value -> Fallible a) -> Value -> Fallible a
assertValue get = \case
	OpValue op -> run op >>= get
	other -> error $ "An int was expected, but instead, it's a(n) " ++ show other ++ "!"

asNativeString :: Value -> Fallible Text
asNativeString = \case
	NativeStringValue text -> return text
	other -> assertValue asNativeString other

asInt :: Value -> Fallible Int32
asInt = \case  -- TODO TEMPORARY
	BitsValue bytes -> do
		let (b1:(b2:(b3:(b4:_)))) = BS.unpack bytes
		return $ (shiftL (fromIntegral b1) 24) .|.
			(shiftL (fromIntegral b2) 16) .|.
			(shiftL (fromIntegral b3) 8) .|.
			(fromIntegral b4)
	other -> assertValue asInt other

intValue :: Int32 -> Value
intValue int = BitsValue $ BS.pack $
	map (fromInteger . toInteger . (.&. 0xFF) . shiftR int) [24, 16, 8, 0]

-- builtin enumeration

{- This enum-based system is used to allow definitions to be referenced while building the
   context despite the fact that they receive their Location when the Context is built.
   The location of Builtin ops is simply derived from their index in the Context, so by
   relating the definitions to an enum and pushing the definitions into the Context
   in Enum order when we build it, we can know the index of each Definition early.

   Yes, it's extremely inconvenient and if Haskell had more advanced Enum structures like
   Java or Beng, this wouldn't be such a pain. -}

data BuiltinOp =
	Integers |
	Add | Subtract |
	DefineValue | If
	deriving (Show, Eq, Enum, Ord)

instance HasField "definition" BuiltinOp Definition where
	getField = definitionOf hangingDefinitionOf

instance HasField "declaration" BuiltinOp Declaration where
	getField = declarationOf hangingDefinitionOf

hangingDefinitionOf :: BuiltinOp -> Location -> Definition
hangingDefinitionOf opEnum location = case opEnum of
	-- Types of the arguments and the values in these definitions are disjointed,
	-- losing all type guarantees. This will not be an issue in Beng! :)
	Integers -> define None
		[t "Integer" $ multi $ c [cr '0' '9']]
		intType
		(\args -> do
			text <- asNativeString $ args ! "Integer"
			-- `read :: Int` is safe because we only match '0'-'9'.
			return $ intValue (read $ unpack text :: Int32))
		location
	Add -> define Default
		[a "Augend" intType, s, l "+", s, a "Addend" intType]
		intType
		(\args -> do
			augend <- asInt $ args ! "Augend"
			addend <- asInt $ args ! "Addend"
			return $ intValue $ augend + addend)
		location
	Subtract -> define (At $ dec Add)
		[a "Minuend" intType, s, l "-", s, a "Subtrahend" intType]
		intType
		(\args -> do
			minuend <- asInt $ args ! "Minuend"
			subtrahend <- asInt $ args ! "Subtrahend"
			return $ intValue $ minuend - subtrahend)
		location
	DefineValue -> defineUsing (Below $ dec Add) Righty
		[t "Name" valueName, s, l ":=", s, a "Value" intType, s, a "Scope" PreOpType]
		intType
		(\name args location -> case name of
			"Scope" -> do
				name <- asNativeString $ value $ args ! "Name"
				let value = (args ! "Value").value
				return [DefCard $ defineLiteral name intType value location]
			_ -> return [])
		(\args -> run $ asOp $ args ! "Scope")
		location
	If -> do
		let branchType = OpType { args = Map.empty, returnType = intType }
		define (Below $ dec DefineValue)
			[l "if", s, a "Condition" intType, l ",", s, a "Y" branchType, s, l "else", s, a "N" branchType]
			intType
			(\args -> do
				condition <- asInt $ args ! "Condition"
				return $ args ! (if condition > 0 then "Y" else "N"))
			location
	where
		a name = do
			-- Since we're building the builtin ops, it must be a Builtin location.
			-- I wish I could just declare that in the type. DataKinds, maybe? I can't figure that out.
			let (Builtin parentIndex) = location
			argAt BuiltinArg { name, parentIndex } name
		t name = do
			let (Builtin parentIndex) = location
			textAt BuiltinArg { name, parentIndex } name
		dec = declarationOf hangingDefinitionOf

-- exported

context :: Context
context = buildContextFrom hangingDefinitionOf Integers