module Beng.Run.Ops (
	run
) where

import Utils.Errors

import qualified Beng.Parse.Matches as Match
import Beng.Run.Values (Value)
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Definitions (Definition(..))

import qualified Data.Map as Map
import Data.Map (Map)
import qualified Data.Map.Ordered as OMap
import Data.Map.Ordered (OMap)

run :: Op -> Fallible Value
run op = case op.card.definition of
	Just Definition{runWith} -> (runArgs $ Match.getArgs op.match) >>= runWith
	Nothing -> toError $ show op.card.declaration ++ " cannot be run without being defined!"
	where
		runArgs :: (OMap String Op -> Fallible (Map String Value))
		runArgs = fmap Map.fromList . reduceErrors . map runArg . OMap.assocs

		runArg :: (String, Op) -> Fallible (String, Value)
		runArg (name, op) = fmap (name,) $ run op