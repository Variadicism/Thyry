module Beng.Run where

import Beng.Types.Errors (Fallible)
import Beng.Ops.Types (Op)
import Beng.Values.Types (Value)

run :: Op -> Fallible Value