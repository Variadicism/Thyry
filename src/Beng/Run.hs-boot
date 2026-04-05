module Beng.Run where

import Beng.Types.Errors (Fallible)
import Beng.Types.Invocations (SomeInvocation)
import Beng.Types.Things (SomeThing)

run :: SomeInvocation -> Fallible SomeThing
