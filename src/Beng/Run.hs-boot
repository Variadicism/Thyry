module Beng.Run where

import Beng.Types.Errors (Fallible)
import Beng.Types.Invocations (Invocation)
import Beng.Types.Operators (Operator)
import Beng.Types.Things (SomeThing)

run :: Operator op => Invocation op -> Fallible SomeThing
