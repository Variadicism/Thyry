module Beng.Types.Things (
	Mismatch(..),
	Undefined(..),
	Thing(..),
	SomeThing(..),
	OpType(..),
	DefinitionType(..),
	DeclarationType(..),
	PatternType(..),
	PreOpType(..),
	NativeBitsValue(..),
	NativeCharValue(..),
	NativeStringValue(..),
	NativeListValue(..),
	NativeSomeValue(..),
	NativeOptionalValue(..),
	NativeType(..),
	NativeBitsType(..),
	NativeCharType(..),
	NativeStringType(..),
	NativeListType(..),
	NativeSomeType(..),
	NativeOptionalType(..),
	NativeOrType(..),
	One(..),
	CombinedThings(..),
	NamedThing(..),
	castThing
) where

import Utils.Fallible (FallibleI)
import Utils.Messaging (Messagable)
import Utils.Populace (Populace)
import Utils.Populace.Populace2 (Populace2)

import {-# SOURCE #-} Beng.Types.Build.TypeTest (TypeTest)
import Beng.Types.Operators (SomeOperator)
import {-# SOURCE #-} Beng.Types.Operators.Declarations (Declaration)
import {-# SOURCE #-} qualified Beng.Types.Operators.Declarations as Declaration

import Data.ByteString (ByteString)
import Data.Map (Map)
import Data.Text.Lazy (Text)
import Data.Typeable (Typeable, cast)

data SomeThing = forall thing. Thing thing => SomeThing thing

data Mismatch =
	MismatchedArgument {
		name :: String,
		super :: SomeThing,
		sub :: SomeThing,
		cause :: Mismatch } |
	MissingArgument {
		name :: String,
		sub :: SomeThing,
		superArgs :: Map String SomeThing } |
	ExtraArgument {
		name :: String,
		super :: SomeThing,
		subArgs :: Map String SomeThing } |
	UnsatisfiedProperty { property :: SomeOperator, decMismatch :: Declaration.Mismatch } |
	ObscuredProperty { property :: SomeOperator, decMismatch :: Declaration.Mismatch } |
	UnsatisfiedParent {
		parent :: SomeThing,
		super :: SomeThing,
		cause :: Mismatch } |
	PrimitiveMismatch { super :: SomeThing, sub :: SomeThing } |
	Tautology { super :: SomeThing, sub :: SomeThing } |
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

data Undefined = Undefined { decsByContext :: [(String, Declaration)] }

class (Eq thing, Show thing, Messagable thing, Typeable thing) => Thing thing where
	satisfies :: ((TypeTest, thing) -> SomeThing -> FallibleI Mismatch ())
	propsWith _ _ = []
	propsWith :: (thing -> SomeThing -> [SomeOperator])
	toCode :: (thing -> Text)

data OpType = OpType {
	args :: Map String SomeThing,
	returnType :: SomeThing }

data DefinitionType = DefinitionType

data DeclarationType = DeclarationType

data PatternType = PatternType

data PreOpType t = PreOpType { resolvedType :: t }

data NativeBitsValue = NativeBitsValue {
	bytes :: ByteString,
	size :: Int }

data NativeCharValue = NativeCharValue { char :: Char }

data NativeStringValue = NativeStringValue { text :: Text }

data NativeListValue = NativeListValue { values :: [SomeThing] }

data NativeSomeValue = NativeSomeValue { valuesP :: Populace SomeThing }

data NativeOptionalValue t = NativeOptionalValue { fal :: FallibleI Undefined t }

data NativeType = NativeType { properties :: SomeThing -> [SomeOperator] }

data NativeBitsType = NativeBitsType { size :: Int }

data NativeCharType = NativeCharType

data NativeStringType = NativeStringType

data NativeListType t = NativeListType { elementType :: t }

data NativeSomeType t = NativeSomeType { elementType :: t }

data NativeOptionalType t = NativeOptionalType { falueType :: t }

data NativeOrType = NativeOrType { options :: Populace2 SomeThing }

data One = One

data CombinedThings = CombinedThings { things :: Populace2 SomeThing }

data NamedThing t = NamedThing {
	name :: String,
	value :: t }

castThing :: forall thing. Thing thing => SomeThing -> Maybe thing
castThing (SomeThing thing) = cast thing
