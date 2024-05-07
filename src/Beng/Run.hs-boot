module Beng.Run where

import Beng.Types.Errors (Fallible)
import Beng.Types.Ops (Op)
import Beng.Types.Values (Value)

run :: Op -> Fallible Value