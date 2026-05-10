module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2

import Beng.Types.Operators (SomeOperator(..))
import Beng.Types.Invocations (SomeInvocation(..))
import Beng.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Build.Context.Builders (c, cr, e, nc, s, l, multi, argAt, asBits, asInt, asList, asNativeString, asInv, asSome, bitType, bitValue, buildContextFrom, declarationOf, define, defineUsing, defineLiteral, definitionOf, intType, intValue, listOfP, orTP, someOfP, stringType, stringValue, textAt, thingP)
import Beng.Types.Parse.Matches (matchedType, value)
import Beng.Types.Parse.Patterns (And(..), Delimited(..), Or(..), SomePattern(..))
import Beng.Run (run, runWhileOp)
import Beng.Types.Operators.Declarations (Associativity(..), Declaration)
import Beng.Types.Operators.Definitions (Definition(..))
import Beng.Types.Locations (Location(..))
import Beng.Things (PreOpType(..))
import Beng.Types.Things (NativeListValue(..), NativeSomeValue(..), Parameter(..), SomeConcreteThing(..), SomeParameterizedThing(..), SomeThing(..), NativeBitsType(..), parameterize)

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
	LineComment | LineCommentEnd |
	Ints | Strings | Yes | No |
	IntType | BitType |
	Add | Subtract | Equal |
	StartsWith |
	EmptyList | ConcatLists |
	Only | First | ConcatListSome |
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
	LineComment -> define Default
		[l "#", t "Content" $ multi $ nc [cr '\n' '\n'], l "\n", a "Value" (p "V" thingP)]
		(p "V" thingP)
		(\args -> return $ args ! "Value")
		location
	LineCommentEnd -> define Default
		[a "Value" (p "V" thingP), l "#", t "Content" $ multi $ nc [cr '\n' '\n']]
		(p "V" thingP)
		(\args -> return $ args ! "Value")
		location
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
		(\_ -> return $ SomeThing $ NativeBitsType 32)
		location
	BitType -> define None
		[l "a bit"]
		bitType
		(\_ -> return $ SomeThing $ NativeBitsType 1)
		location
	Yes -> define None
		[l "yes"]
		(SomeParameterizedThing $ NativeBitsType 1)
		(\_ -> return $ bitValue True)
		location
	No -> define None
		[l "no"]
		(SomeParameterizedThing $ NativeBitsType 1)
		(\_ -> return $ bitValue False)
		location
	Add -> define (Broader $ SomeOperator $ dec LineComment)
		[a "Augend" intType, s, l "+", s, a "Addend" intType]
		intType
		(\args -> do
			augend <- asInt $ args ! "Augend"
			addend <- asInt $ args ! "Addend"
			return $ intValue $ augend + addend)
		location
	Subtract -> define (SameAs $ SomeOperator $ dec Add)
		[a "Minuend" intType, s, l "-", s, a "Subtrahend" intType]
		intType
		(\args -> do
			minuend <- asInt $ args ! "Minuend"
			subtrahend <- asInt $ args ! "Subtrahend"
			return $ intValue $ minuend - subtrahend)
		location
	Equal -> define (Tighter $ SomeOperator $ dec Subtract)
		[a "Left" thingP, s, l "=", s, a "Right" thingP]
		bitType
		(\args -> return $ bitValue $ args ! "Left" == args ! "Right")
		location
	EmptyList -> define None
		[l "nothing"]
		(listOfP thingP)
		(const $ return $ SomeThing $ NativeListValue ([] :: [SomeConcreteThing]))
		location
	ConcatLists -> define (Broader $ SomeOperator $ dec Equal)
		[a "Init" (p "L" $ listOfP thingP), s, l "and", s, a "Tail" $ (p "L" $ listOfP thingP)]
		(p "L" $ listOfP thingP)
		(\args -> do
			initL <- asList $ args ! "Init"
			tailL <- asList $ args ! "Tail"
			return $ SomeThing $ NativeListValue $ initL ++ tailL)
		location
	Only -> define (Broader $ SomeOperator $ dec Add)
		[l "only", s, a "Only" $ p "O" thingP]
		(someOfP $ p "O" thingP)
		(\args -> return $ SomeThing $ NativeSomeValue $ P.singleton $ args ! "Only")
		location
	First -> define (Broader $ SomeOperator $ dec Add)
		[l "First", s, l "of", s, a "Some" $ someOfP $ p "E" thingP]
		(p "E" thingP)
		(\args -> do
			someValue <- asSome $ args ! "Some"
			case P.uncons someValue of
				(first, _) -> return first)
		location
	ConcatListSome -> define (SameAs $ SomeOperator $ dec ConcatLists)
		[a "Init" (p "L" $ listOfP thingP), s, l "and", s, a "Tail" $ (p "L" $ someOfP thingP)]
		(p "L" $ listOfP thingP)
		(\args -> do
			initL <- asList $ args ! "Init"
			tailSome <- asSome $ args ! "Tail"
			return $ SomeThing $ NativeSomeValue $ P.assume $ initL ++ tailSome.l)
		location
	StartsWith -> define (Tighter $ SomeOperator $ dec Add)
		[a "Target" stringType, s, l "starts", s, l "with", s, a "Prefix" stringType]
		bitType
		(\args -> do
			target <- asNativeString $ args ! "Target"
			prefix <- asNativeString $ args ! "Prefix"
			return $ bitValue $ prefix `Text.isPrefixOf` target)
		location
	DefineValue -> defineUsing (Tighter $ SomeOperator $ dec Add) Righty
		[t "Name" valueName, s, l ":=", s, a "Value" thingP, s,
			a "Scope" (SomeParameterizedThing $ PreOpType $ p "R" thingP)]
		(p "R" thingP)
		(\name args location -> case name of
			"Scope" -> do
				name <- asNativeString $ (args ! "Name").value
				let value = (args ! "Value").value
				let valueType = parameterize $ (args ! "Value").matchedType
				return [SomeOperator $ defineLiteral name valueType value location]
			_ -> return [])
		(\args -> case asInv $ args ! "Scope" of
			SomeInvocation invocation -> run invocation)
		location
	If -> define (Tighter $ SomeOperator $ dec DefineValue)
		[l "if", s, a "Condition" bitType, l ",", s,
			a "Yes Value" (p "Y" thingP), s,
			l "else", s,
			a "No Value" (p "N" thingP)]
		((p "Y" thingP) `orTP` (p "N" thingP))
		(\args -> do
			conditionValue <- runWhileOp $ args ! "Condition"
			bytestring <- asBits 1 conditionValue
			let [bit] = BS.unpack bytestring
			return $ args ! (if bit > 0 then "Yes Value" else "No Value"))
		location
	where
		a :: String -> SomeParameterizedThing -> SomePattern
		a name = do
			-- Since we're building the builtin ops, it must be a Builtin location.
			-- I wish I could just declare that in the type. DataKinds, maybe? I can't figure that out.
			let (Builtin parentIndex) = location
			argAt BuiltinArg { name, parentIndex } name
		p :: String -> SomeParameterizedThing -> SomeParameterizedThing
		p name baseType = do
			let (Builtin parentIndex) = location
			SomeParameterizedThing Parameter { name, baseType, decLoc = BuiltinArg { name, parentIndex }}
		t name = do
			let (Builtin parentIndex) = location
			textAt BuiltinArg { name, parentIndex } name
		dec = declarationOf hangingDefinitionOf

-- exported

context :: Context
context = buildContextFrom hangingDefinitionOf LineComment
