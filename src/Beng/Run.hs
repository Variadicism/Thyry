module Beng.Run (
	run
) where

import Utils.Fallible hiding (Fallible)
import qualified Utils.Maps.Ordered as OMap

import Beng.Ops (Op(..), getArgs)
import Beng.Errors (Error(..), Fallible)
import Beng.Ops.Types.Definitions (Definition(..))
import Beng.Parse.Types.Matches (value)
import Beng.Values.Types (Value)

import qualified Data.Map.Ordered as OMap

run :: Op -> Fallible Value
run op = case op.card.definition of
	Nothing -> Error $ UndefinedError {
		context = "", declaration = op.card.declaration, caller = op, callLocation = op.location }
	Just definition -> definition.runWith $ OMap.toMap $ OMap.map value $ getArgs op