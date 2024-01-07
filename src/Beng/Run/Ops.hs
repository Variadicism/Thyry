module Beng.Run.Ops (
	run
) where


import Beng.Parse.Types.Arguments (definition, name, op)
import qualified Beng.Parse.Matches as Match
import Beng.Run.Values (Value)
import Beng.Types.Definitions (Definition(..))
import Beng.Types.Ops (Op(..))

import qualified Data.Map as Map

{- There is a subtly represented but CRUCIAL property of Beng noted here: this result is NOT Fallible!
   This should ALWAYS HOLD TRUE!
   If this language compiles, it should be able to run without EVER throwing an error!!
   Errors will be handled inside the program and can print messages and close or whatever,
      but the program CANNOT CRASH! -}
run :: Op -> Value
run op = op.definition.runWith $
	Map.fromList $ map (\match -> (match.definition.name, run match.op)) $
	Match.getArgs op.match