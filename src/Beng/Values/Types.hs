module Beng.Values.Types (
	Undefined(..),
	Type(..),
	Value(..)
) where

import Utils.Fallible (FallibleI)
import Utils.Populace (Populace)

import Beng.Build.Types.Cards (Card)
import {-# SOURCE #-} Beng.Ops ()
import {-# SOURCE #-} Beng.Ops.Types.Declarations (Declaration)
import {-# SOURCE #-} Beng.Ops.Types.Definitions (Definition)
import {-# SOURCE #-} Beng.Ops.Types (Op)
import Beng.Parse.Types.Patterns (Pattern)

import Data.ByteString (ByteString)
import Data.Map (Map)
import Data.Text.Lazy (Text)

data Undefined = Undefined { decsByContext :: [(String, Declaration)] }

data Type =
	-- primitives
	ThingType |
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
	NativeOptionalType { falueType :: Type }

data Value =
	-- primitives
	-- Everything is a thing and a thing provides definitions for all the properties of all its types.
	ThingValue { definitions :: Populace Definition } |
	TypeValue { parents :: Populace Type, properties :: [Card] } |
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
