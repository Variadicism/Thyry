module Beng.Types.Things (
	Mismatch(..),
	Undefined(..),
	Thing(..)
) where

import Utils.Fallible (FallibleI)
import Utils.Populace (Populace)
import Utils.Populace.Populace2 (Populace2)

import {-# SOURCE #-} Beng.Invocations ()
import Beng.Types.Operators (SomeOperator)
import {-# SOURCE #-} Beng.Types.Operators.Declarations (Declaration)
import {-# SOURCE #-} qualified Beng.Types.Operators.Declarations as Declaration
import {-# SOURCE #-} Beng.Types.Operators.Definitions (Definition)
import {-# SOURCE #-} Beng.Types.Invocations (SomeInvocation)
import {-# SOURCE #-} Beng.Types.Parse.Patterns (SomePattern)

import Data.ByteString (ByteString)
import Data.Map (Map)
import Data.Text.Lazy (Text)

data Mismatch =
	-- \/ closest to success
	MismatchedArgument { name :: String, super :: Thing, sub :: Thing, cause :: Mismatch } |
	MissingArgument { name :: String, sub :: Thing, superArgs :: Map String Thing } |
	ExtraArgument { name :: String, super :: Thing, subArgs :: Map String Thing } |
	UnsatisfiedProperty { property :: SomeOperator, decMismatch :: Declaration.Mismatch } |
	ObscuredProperty { property :: SomeOperator, decMismatch :: Declaration.Mismatch } |
	UnsatisfiedParent { parent :: Thing, super :: Thing, cause :: Mismatch } |
	PrimitiveMismatch { super :: Thing, sub :: Thing } |
	Tautology { super :: Thing, sub :: Thing } |
	-- /\ furthest from success
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

data Undefined = Undefined { decsByContext :: [(String, Declaration)] }

data Thing =
	-- primitive values: basic building blocks of the language
	InvValue SomeInvocation |
	DefinitionValue Definition |
	DeclarationValue Declaration |
	PatternValue SomePattern |
	-- TODO: PreOpValue
	-- primitive types: types representing the primitive values
	-- TODO: these should be replaceable when the type system is more fleshed out and stable
	OpType { args :: Map String Thing, returnType :: Thing } |
	DefinitionType |
	DeclarationType |
	PatternType |
	PreOpType { resolvedType :: Thing } |
	-- native values: values necessary for runtime with language-level equivalents
	NativeBitsValue { bytes :: ByteString, size :: Int {- in BITS, not bytes -} } |
	NativeCharValue { char :: Char } |
	NativeStringValue { text :: Text } |
	NativeListValue { values :: [Thing] } |
	NativeSomeValue { valuesP :: Populace Thing } |
	NativeOptionalValue { fal :: FallibleI Undefined Thing } |
	-- native types: types representing the native values
	NativeType { properties :: Thing -> [SomeOperator] } |
	NativeBitsType { size :: Int } |
	NativeCharType |
	NativeStringType |
	NativeListType { elementType :: Thing } |
	NativeSomeType { elementType :: Thing } |
	NativeOptionalType { falueType :: Thing } |
	NativeOrType { options :: Populace2 Thing } |
	-- meta values: values representing value configurations
	One |  -- used as a placeholder in defining properties at the language level
	CombinedThings { things :: Populace2 Thing } |
	NamedThing { name :: String, value :: Thing }
