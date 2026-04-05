module Beng.Run where

import Beng.Types.Errors (Fallible)
import Beng.Types.Invocations (SomeInvocation)
import Beng.Types.Things (Thing)

run :: SomeInvocation -> Fallible Thing
