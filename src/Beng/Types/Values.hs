module Beng.Types.Values (
	Mismatch(..),
	Undefined(..),
	Type(..),
	Value(..)
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
	MismatchedArgument { name :: String, super :: Type, sub :: Type, cause :: Mismatch } |
	MissingArgument { name :: String, sub :: Type, superArgs :: Map String Type } |
	ExtraArgument { name :: String, super :: Type, subArgs :: Map String Type } |
	UnsatisfiedProperty { property :: Declaration, decMismatch :: Declaration.Mismatch } |
	UnsatisfiedParent { parent :: Type, super :: Type, cause :: Mismatch } |
	PrimitiveMismatch { super :: Type, sub :: Type } |
	-- /\ furthest from success
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

data Undefined = Undefined { decsByContext :: [(String, Declaration)] }

data Type =
	-- primitives
	ThingType { name :: Maybe String, parents :: [Type], properties :: Type -> [Card] } |
	TypeType |
	BitsType { size :: Int } |
	OpType { args :: Map String Type, returnType :: Type } |
	DefinitionType |
	DeclarationType |
	PatternType |
	PreOpType |
	-- natives
	NativeCharType |
	NativeStringType |
	NativeListType { elementType :: Type } |
	NativeSomeType { elementType :: Type } |
	NativeOptionalType { falueType :: Type } |
	NativeOrType { options :: Populace2 Type }

data Value =
	-- primitives
	-- Everything is a thing and a thing provides definitions for all the properties of all its types.
	ThingValue { definitions :: Populace Definition } |
	TypeValue Type |
	BitsValue { bytes :: ByteString } |
	OpValue Op |
	DefinitionValue Definition |
	DeclarationValue Declaration |
	PatternValue Pattern |
	-- TODO: PreOps (How can I make sure they have the context before they need to be parsed?)
	-- natives
	NativeCharValue { char :: Char } |
	NativeStringValue { text :: Text } |
	NativeListValue { values :: [Value] } |
	NativeSomeValue { valuesP :: Populace Value } |
	NativeOptionalValue { fal :: FallibleI Undefined Value }
