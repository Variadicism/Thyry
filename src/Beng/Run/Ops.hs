module Beng.Run.Ops (
	run
) where


import qualified Beng.Parse.Matches as Match
import Beng.Run.Values (Value)
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Definitions (Definition(..))

import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap

{- There is a subtly represented but CRUCIAL property of Beng noted here: this result is NOT Fallible!
   This should ALWAYS HOLD TRUE!
   If this language compiles, it should be able to run without EVER throwing an error!!
   Errors will be handled inside the program and can print messages and close or whatever,
      but the program CANNOT CRASH! -}
run :: Op -> Value
run op = op.definition.runWith $
	Map.map run $ OMap.toMap $ Match.getArgs op.match