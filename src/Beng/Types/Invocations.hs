module Beng.Types.Invocations (
	Invocation(..),
	SomeInvocation(..)
) where

import Beng.Types.Operators (Operator)
import {-# SOURCE #-} Beng.Types.Build.Context (Context)
import Beng.Types.Parse.Matches (SomeMatch)
import Beng.Types.Locations (Location)
import {-# SOURCE #-} Beng.Types.Things (SomeConcreteThing)

data Invocation op = Invocation {
	operator :: op,
	context :: Context,
	location :: Location,
	match :: SomeMatch,
	-- TODO: compute returnType?
	returnType :: SomeConcreteThing }

data SomeInvocation = forall op. Operator op => SomeInvocation (Invocation op)
