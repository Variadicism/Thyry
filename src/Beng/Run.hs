module Beng.Run (
	run,
	runWhileOp
) where

import Utils.Fallible hiding (Fallible)
import qualified Utils.Maps.Ordered as OMap

import Beng.Ops (Op(..), getArgs)
import Beng.Errors (Error(..), Fallible)
import Beng.Types.Ops.Definitions (Definition(..))
import Beng.Types.Parse.Matches (value)
import Beng.Types.Things (Thing(OpValue))

import qualified Data.Map.Ordered as OMap

run :: Op -> Fallible Thing
run op = case op.card.definition of
	Nothing -> Error $ UndefinedError {
		context = "", declaration = op.card.declaration, caller = op, callLocation = op.location }
	Just definition -> definition.runWith $ OMap.toMap $ OMap.map value $ getArgs op

runWhileOp :: Thing -> Fallible Thing
runWhileOp = \case
	OpValue op -> run op >>= runWhileOp
	value -> return value