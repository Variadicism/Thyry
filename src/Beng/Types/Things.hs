module Beng.Types.Things (
	Mismatch(..),
	Undefined(..),
	ResolveError(..),
	Binding(..),
	Thing(..),
	ConcreteThing,
	ParameterizedThing(..),
	SomeThing(..),
	SomeConcreteThing(..),
	SomeParameterizedThing(..),
	OpType(..),
	DefinitionType(..),
	DeclarationType(..),
	PatternType(..),
	Parameter(..),
	ParameterMatches,
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
	castThing,
	castConcreteThing,
	castParameterizedThing
) where

import Utils.Fallible (FallibleI(..))
import Utils.Messaging (Messagable)
import Utils.Populace (Populace)
import Utils.Populace.Populace2 (Populace2)

import {-# SOURCE #-} Beng.Types.Build.TypeTest (TypeTest)
import Beng.Locations ()
import Beng.Types.Locations (Location)
import Beng.Types.Operators (SomeOperator)
import {-# SOURCE #-} Beng.Types.Operators.Declarations (Declaration)
import {-# SOURCE #-} qualified Beng.Types.Operators.Declarations as Declaration

import Data.ByteString (ByteString)
import Data.Map (Map)
import Data.Text.Lazy (Text)
import Data.Typeable (Typeable, cast)

data SomeThing = forall thing. Thing thing => SomeThing thing
data SomeConcreteThing = forall thing. ConcreteThing thing => SomeConcreteThing thing
data SomeParameterizedThing =
	forall thing. ParameterizedThing thing => SomeParameterizedThing thing

data Mismatch =
	MismatchedArgument {
		name :: String,
		candidate :: SomeThing,
		requirement :: SomeThing,
		cause :: Mismatch } |
	MissingArgument {
		name :: String,
		requirement :: SomeThing,
		candidateArgs :: Map String SomeThing } |
	ExtraArgument {
		name :: String,
		candidate :: SomeThing,
		requirementArgs :: Map String SomeThing } |
	UnsatisfiedProperty { property :: SomeOperator, decMismatch :: Declaration.Mismatch } |
	ObscuredProperty { property :: SomeOperator, decMismatch :: Declaration.Mismatch } |
	UnsatisfiedParent {
		parent :: SomeThing,
		candidate :: SomeThing,
		cause :: Mismatch } |
	PrimitiveMismatch { candidate :: SomeThing, requirement :: SomeThing } |
	Tautology { candidate :: SomeThing, requirement :: SomeThing } |
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

data Undefined = Undefined { decsByContext :: [(String, Declaration)] }

data ResolveError =
	MissingParameter {
		parameter :: Parameter,
		availableMatches :: ParameterMatches } |
	CompoundResolveError {
		contexts :: [String],
		compound :: Populace ResolveError }

data Binding = Binding {
	location :: Location,
	thing :: SomeParameterizedThing }

class (Eq thing, Show thing, Messagable thing, Typeable thing) => Thing thing where
	toCode :: thing -> Text
	propsWith :: thing -> SomeThing -> [SomeOperator]
	propsWith _ _ = []
	normalize :: thing -> SomeThing
	normalize = SomeThing
	parameterize :: thing -> SomeParameterizedThing
	asParameter :: thing -> Maybe Parameter
	asParameter _ = Nothing
	satisfiesAsCandidate
		:: TypeTest -> thing -> SomeParameterizedThing -> Maybe (FallibleI Mismatch TypeTest)
	satisfiesAsCandidate _ _ _ = Nothing

class Thing thing => ConcreteThing thing

class Thing thing => ParameterizedThing thing where
	satisfies
		:: (TypeTest, SomeThing) -> thing -> FallibleI Mismatch TypeTest
	satisfies (_, candidate) requirement =
		Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve :: ParameterMatches -> thing -> FallibleI ResolveError SomeConcreteThing

data OpType = OpType {
	args :: Map String SomeParameterizedThing,
	returnType :: SomeParameterizedThing }

data DefinitionType = DefinitionType

data DeclarationType = DeclarationType

data PatternType = PatternType

-- TODO: move this to the Operator definition and replace this was a placeholder by name.
data Parameter = Parameter {
	decLoc :: Location,
	name :: String,
	baseType :: SomeParameterizedThing }

type ParameterMatches = Map Parameter (Populace Binding)

instance Eq Parameter where
	parameter1 == parameter2 = parameter1.decLoc == parameter2.decLoc

instance Ord Parameter where
	compare parameter1 parameter2 = compare parameter1.decLoc parameter2.decLoc

data PreOpType t = PreOpType { resolvedType :: t }

data NativeBitsValue = NativeBitsValue {
	bytes :: ByteString,
	size :: Int }

data NativeCharValue = NativeCharValue { char :: Char }

data NativeStringValue = NativeStringValue { text :: Text }

data NativeListValue t = NativeListValue { values :: [t] }

data NativeSomeValue t = NativeSomeValue { valuesP :: Populace t }

data NativeOptionalValue t = NativeOptionalValue { fal :: FallibleI Undefined t }

data NativeType = NativeType { properties :: SomeThing -> [SomeOperator] }

data NativeBitsType = NativeBitsType { size :: Int }

data NativeCharType = NativeCharType

data NativeStringType = NativeStringType

data NativeListType t = NativeListType { elementType :: t }

data NativeSomeType t = NativeSomeType { elementType :: t }

data NativeOptionalType t = NativeOptionalType { falueType :: t }

data NativeOrType t = NativeOrType { options :: Populace2 t }

data One = One

data CombinedThings t = CombinedThings { things :: Populace2 t }

data NamedThing t = NamedThing {
	name :: String,
	value :: t }

castThing :: forall thing. Thing thing => SomeThing -> Maybe thing
castThing (SomeThing thing) = cast thing

castConcreteThing :: forall thing. ConcreteThing thing => SomeConcreteThing -> Maybe thing
castConcreteThing (SomeConcreteThing thing) = cast thing

castParameterizedThing
	:: forall thing. ParameterizedThing thing => SomeParameterizedThing -> Maybe thing
castParameterizedThing (SomeParameterizedThing thing) = cast thing
