module Beng.Things where

import Utils.Fallible (FallibleI, IsError)
import Utils.Messaging (Messagable)

import Beng.Types.Operators (SomeOperator)
import Beng.Types.Build.Context (Context)
import Beng.Types.Invocations (SomeInvocation)
import Beng.Types.Operators.Declarations (Declaration)
import Beng.Types.Operators.Definitions (Definition)
import Beng.Types.Build.TypeTest (TypeTestResult)
import Beng.Types.Things (
	Mismatch,
	ParameterizedThing,
	ResolveError,
	SomeConcreteThing,
	SomeParameterizedThing,
	SomeThing,
	Thing,
	Undefined)

instance Eq Mismatch

instance Show Mismatch

instance Messagable Mismatch

instance Ord Mismatch

instance IsError Mismatch

instance Show ResolveError

instance IsError ResolveError

instance Eq SomeThing

instance Show SomeThing

instance Messagable SomeThing

instance Eq SomeParameterizedThing

instance Show SomeParameterizedThing

instance Messagable SomeParameterizedThing

instance Thing SomeParameterizedThing

instance ParameterizedThing SomeParameterizedThing

instance Thing SomeConcreteThing

instance Thing SomeInvocation

undefined :: Declaration -> FallibleI Undefined SomeThing

propsOf :: SomeThing -> [SomeOperator]

defsOf :: SomeThing -> [Definition]

satisfiesThing :: (Context, SomeThing) -> SomeParameterizedThing -> TypeTestResult
