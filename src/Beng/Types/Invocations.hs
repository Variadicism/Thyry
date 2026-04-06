module Beng.Types.Invocations (
	Invocation(..),
	SomeInvocation(..)
) where

import Beng.Types.Operators (Operator)
import {-# SOURCE #-} Beng.Types.Build.Context (Context)
import Beng.Types.Parse.Matches (SomeMatch)
import Beng.Types.Locations (Location)

data Invocation op = Invocation {
	operator :: op,
	context :: Context,
	location :: Location,
	match :: SomeMatch }

data SomeInvocation = forall op. Operator op => SomeInvocation (Invocation op)
