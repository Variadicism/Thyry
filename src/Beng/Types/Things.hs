module Beng.Types.Things (
	Mismatch(..),
	Undefined(..),
	Thing(..)
) where

import Utils.Fallible (FallibleI)
import Utils.Populace (Populace)
import Utils.Populace.Populace2 (Populace2)

import Beng.Types.Build.Cards (Card)
import {-# SOURCE #-} Beng.Ops ()
import {-# SOURCE #-} Beng.Types.Ops.Declarations (Declaration)
import {-# SOURCE #-} qualified Beng.Types.Ops.Declarations as Declaration
import {-# SOURCE #-} Beng.Types.Ops.Definitions (Definition)
import {-# SOURCE #-} Beng.Types.Ops (Op)
import Beng.Types.Parse.Patterns (Pattern)

import Data.ByteString (ByteString)
import Data.Map (Map)
import Data.Text.Lazy (Text)

data Mismatch =
	-- \/ closest to success
	MismatchedArgument { name :: String, super :: Thing, sub :: Thing, cause :: Mismatch } |
	MissingArgument { name :: String, sub :: Thing, superArgs :: Map String Thing } |
	ExtraArgument { name :: String, super :: Thing, subArgs :: Map String Thing } |
	UnsatisfiedProperty { property :: Declaration, decMismatch :: Declaration.Mismatch } |
	UnsatisfiedParent { parent :: Thing, super :: Thing, cause :: Mismatch } |
	PrimitiveMismatch { super :: Thing, sub :: Thing } |
	-- /\ furthest from success
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

data Undefined = Undefined { decsByContext :: [(String, Declaration)] }

data Thing =
	-- primitive values: basic building blocks of the language
	ThingValue { definitions :: Populace Definition } |
	OpValue Op |
	DefinitionValue Definition |
	DeclarationValue Declaration |
	PatternValue Pattern |
	-- TODO: PreOpValue
	-- primitive types: types representing the primitive values
	-- TODO: these should be replaceable when the type system is more fleshed out and stable
	OpType { args :: Map String Thing, returnType :: Thing } |
	DefinitionType |
	DeclarationType |
	PatternType |
	PreOpType |
	-- native values: values necessary for runtime with language-level equivalents
	NativeBitsValue { bytes :: ByteString } |
	NativeCharValue { char :: Char } |
	NativeStringValue { text :: Text } |
	NativeListValue { values :: [Thing] } |
	NativeSomeValue { valuesP :: Populace Thing } |
	NativeOptionalValue { fal :: FallibleI Undefined Thing } |
	-- native types: types representing the native values
	NativeType {
		name :: Maybe String,
		parents :: [Thing],
		properties :: Thing -> [Card] } |
	NativeBitsType { size :: Int } |
	NativeCharType |
	NativeStringType |
	NativeListType { elementType :: Thing } |
	NativeSomeType { elementType :: Thing } |
	NativeOptionalType { falueType :: Thing } |
	NativeOrType { options :: Populace2 Thing }