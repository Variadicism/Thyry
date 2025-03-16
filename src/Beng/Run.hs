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
		-- TODO: The declaration and caller should not be the same; I think info is missing.
		declaration = op.card.declaration, caller = op }
	Just definition -> definition.runWith $ OMap.toMap $ OMap.map value $ getArgs op

runWhileOp :: Thing -> Fallible Thing
runWhileOp = \case
	OpValue op -> run op >>= runWhileOp
	value -> return value