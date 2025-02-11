module Beng.Run where

import Beng.Types.Errors (Fallible)
import Beng.Types.Ops (Op)
import Beng.Types.Things (Thing)

run :: Op -> Fallible Thing