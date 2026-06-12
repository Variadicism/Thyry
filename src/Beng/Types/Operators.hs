module Beng.Types.Operators (
	Operator(..),
	SomeOperator(..)
) where

import Utils.Fallible (FallibleI)
import Utils.Messaging (Messagable)

import {-# SOURCE #-} Beng.Types.Build.Context (PrecedenceBound)
import {-# SOURCE #-} Beng.Types.Build.TypeTest (TypeTest)
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (SomeLocation)
import {-# SOURCE #-} Beng.Types.Invocations (Invocation)
import {-# SOURCE #-} Beng.Types.Operators.Declarations (ArgContextBuilder, Associativity)
import {-# SOURCE #-} Beng.Types.Operators.Definitions (Definition)
import {-# SOURCE #-} Beng.Types.Parse.Patterns (SomePattern)
import {-# SOURCE #-} Beng.Types.Things (SomeParameterizedThing, SomeThing)
import {-# SOURCE #-} qualified Beng.Types.Things as Thing

class (Show op, Messagable op) => Operator op where
	location :: op -> SomeLocation
	decLoc :: op -> SomeLocation
	pattern :: op -> SomePattern
	returnType :: op -> SomeParameterizedThing
	associativity :: op -> Associativity
	precedence :: op -> PrecedenceBound
	contextualize :: op -> ArgContextBuilder
	inlineDefinition :: op -> Maybe Definition
	hasProp :: TypeTest -> op -> FallibleI Thing.Mismatch TypeTest
	resolve :: Thing.ParameterMatches -> op -> SomeOperator
	runUsing :: Invocation op -> Fallible SomeThing

data SomeOperator = forall op. Operator op => SomeOperator op
