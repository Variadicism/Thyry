module Beng.Types.Operators (
	Operator(..),
	SomeOperator(..)
) where

import Utils.Fallible (FallibleI)
import Utils.Messaging (Messagable)

import {-# SOURCE #-} Beng.Types.Build.Context (PrecedenceBound)
import {-# SOURCE #-} Beng.Types.Build.TypeTest (TypeTest)
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (Location)
import {-# SOURCE #-} Beng.Types.Invocations (Invocation)
import {-# SOURCE #-} Beng.Types.Operators.Declarations (ArgContextBuilder, Associativity)
import {-# SOURCE #-} Beng.Types.Operators.Definitions (Definition)
import {-# SOURCE #-} Beng.Types.Parse.Patterns (SomePattern)
import {-# SOURCE #-} qualified Beng.Types.Things as Thing

class (Show op, Messagable op) => Operator op where
	location :: op -> Location
	decLoc :: op -> Location
	pattern :: op -> SomePattern
	returnType :: op -> Thing.SomeThing
	associativity :: op -> Associativity
	precedence :: op -> PrecedenceBound
	contextualize :: op -> ArgContextBuilder
	inlineDefinition :: op -> Maybe Definition
	hasProp :: TypeTest -> op -> FallibleI Thing.Mismatch ()
	runUsing :: Invocation op -> Fallible Thing.SomeThing

data SomeOperator = forall op. Operator op => SomeOperator op
