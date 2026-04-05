module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import qualified Utils.Populace.Populace2 as P2

import Beng.Types.Operators (SomeOperator(..))
import Beng.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Build.Context.Builders (c, cr, e, nc, s, l, multi, argAt, asBits, asInt, asNativeString, asInv, bitType, bitValue, buildContextFrom, declarationOf, define, defineUsing, defineLiteral, definitionOf, intType, intValue, stringType, stringValue, textAt)
import Beng.Types.Parse.Matches (value)
import Beng.Types.Parse.Patterns (And(..), Delimited(..), Or(..), SomePattern(..))
import Beng.Run (run, runWhileOp)
import Beng.Types.Operators.Declarations (Associativity(..), Declaration)
import Beng.Types.Operators.Definitions (Definition(..))
import Beng.Types.Locations (Location(..))
import Beng.Types.Things (Thing(..))

import qualified Data.ByteString as BS
import Data.Int (Int32)
import Data.Map ((!))
import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text
import GHC.Records (HasField, getField)

-- constants

type Pattern = SomePattern

valueName :: Pattern
valueName = do
	let uppercaseLetter = c [cr 'A' 'Z']
	let letter = c [cr 'A' 'Z', cr 'a' 'z']
	let capitalizedWord = SomePattern $ And $ P2.dualton uppercaseLetter (SomePattern $ Or $ P2.dualton e $ multi letter)
	SomePattern Delimited { delimiter = s, delimitend = capitalizedWord }

-- builtin enumeration

{- This enum-based system is used to allow definitions to be referenced while building the
   context despite the fact that they receive their Location when the Context is built.
   The location of Builtin ops is simply derived from their index in the Context, so by
   relating the definitions to an enum and pushing the definitions into the Context
   in Enum order when we build it, we can know the index of each Definition early.

   Yes, it's extremely inconvenient and if Haskell had more advanced Enum structures like
   Java or Beng, this wouldn't be such a pain. -}

data BuiltinOp =
	Ints | Strings | Yes | No |
	IntType | BitType |
	Add | Subtract |
	StartsWith |
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
	Ints -> define None
		[t "Integer" $ multi $ c [cr '0' '9']]
		intType
		(\args -> do
			text <- asNativeString $ args ! "Integer"
			-- `read :: Int` is safe because we only match '0'-'9'.
			return $ intValue (read $ unpack text :: Int32))
		location
	Strings -> define None
		[l "\"", t "Content" $ multi $ SomePattern (Or $ P2.dualton (l "\\\"") (nc [cr '"' '"'])), l "\""]
		stringType
		(\args -> do
			text <- asNativeString $ args ! "Content"
			let escaped = Text.replace "\\\"" "\"" $ Text.replace "\\\\" "\\" text
			return $ stringValue escaped)
		location
	IntType -> define None
		[l "an int"]
		intType
		(\_ -> return intType)
		location
	BitType -> define None
		[l "a bit"]
		bitType
		(\_ -> return bitType)
		location
	Yes -> define None
		[l "yes"]
		(NativeBitsType 1)
		(\_ -> return $ bitValue True)
		location
	No -> define None
		[l "no"]
		(NativeBitsType 1)
		(\_ -> return $ bitValue False)
		location
	Add -> define Default
		[a "Augend" intType, s, l "+", s, a "Addend" intType]
		intType
		(\args -> do
			augend <- asInt $ args ! "Augend"
			addend <- asInt $ args ! "Addend"
			return $ intValue $ augend + addend)
		location
	Subtract -> define (At $ SomeOperator $ dec Add)
		[a "Minuend" intType, s, l "-", s, a "Subtrahend" intType]
		intType
		(\args -> do
			minuend <- asInt $ args ! "Minuend"
			subtrahend <- asInt $ args ! "Subtrahend"
			return $ intValue $ minuend - subtrahend)
		location
	StartsWith -> define (Below $ SomeOperator $ dec Add)
		[a "Target" stringType, s, l "starts", s, l "with", s, a "Prefix" stringType]
		bitType
		(\args -> do
			target <- asNativeString $ args ! "Target"
			prefix <- asNativeString $ args ! "Prefix"
			return $ bitValue $ prefix `Text.isPrefixOf` target)
		location
	DefineValue -> defineUsing (Below $ SomeOperator $ dec Add) Righty
		[t "Name" valueName, s, l ":=", s, a "Thing" intType, s, a "Scope" (PreOpType intType)]
		intType
		(\name args location -> case name of
			"Scope" -> do
				name <- asNativeString $ (args ! "Name").value
				let value = (args ! "Thing").value
				return [SomeOperator $ defineLiteral name intType value location]
			_ -> return [])
		(\args -> run $ asInv $ args ! "Scope")
		location
	If -> define (Below $ SomeOperator $ dec DefineValue)
		[l "if", s, a "Condition" (NativeBitsType 1), l ",",
			s, a "Y" intType, s,
			l "else", s, a "N" intType]
		intType
		(\args -> do
			conditionValue <- runWhileOp $ args ! "Condition"
			bytestring <- asBits 1 conditionValue
			let [bit] = BS.unpack bytestring
			return $ args ! (if bit > 0 then "Y" else "N"))
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
context = buildContextFrom hangingDefinitionOf Ints
