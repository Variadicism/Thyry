module Beng.Types.Things where

import Utils.Fallible (FallibleI)
import Utils.Messaging (Messagable)
import Utils.Populace (Populace)

import {-# SOURCE #-} Beng.Types.Build.TypeTest (TypeTest)
import {-# SOURCE #-} Beng.Types.Operators (SomeOperator)
import Data.Map (Map)
import Data.Text.Lazy (Text)
import Data.Typeable (Typeable)

data Mismatch

data Undefined

data ResolveError

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
		:: TypeTest -> thing -> SomeParameterizedThing ->
			Maybe (FallibleI Mismatch TypeTest)
	satisfiesAsCandidate _ _ _ = Nothing

class Thing thing => ConcreteThing thing

class Thing thing => ParameterizedThing thing where
	satisfies
		:: (TypeTest, SomeThing) -> thing -> FallibleI Mismatch TypeTest
	satisfies = satisfies
	resolve :: ParameterMatches -> thing -> FallibleI ResolveError SomeConcreteThing

data SomeThing
data SomeConcreteThing
data SomeParameterizedThing
data Parameter
data Binding

type ParameterMatches = Map Parameter (Populace Binding)
