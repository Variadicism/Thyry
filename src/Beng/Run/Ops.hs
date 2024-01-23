module Beng.Run.Ops (
	runArg,
	run
) where

import Utils.Fallible

import Beng.Parse.Matches (Capture(..))
import Beng.Run.Types.Data (Data)
import Beng.Run.Values (Value(..))
import Beng.Ops (Op(..), getArgs)
import Beng.Types.Ops.Definitions (Definition(..))

import qualified Data.Map.Ordered as OMap

runArg :: Capture -> Fallible Value
runArg = \case
	OpCapture op -> do
		dataOut <- run op
		return $ DataValue dataOut
	StringCapture text -> return $ StringValue text
	ListCapture{captures} -> fmap ListValue $ reduceErrors $ map runArg captures
	MaybeCapture{maybeCapture} -> case maybeCapture of
		Nothing -> return $ MaybeValue Nothing
		Just capture -> fmap (MaybeValue . Just) $ runArg capture

run :: Op -> Fallible Data
run op = case op.card.definition of
	Nothing -> Error $ show op.card.declaration ++ " cannot be run without being defined!"
	Just definition -> definition.runWith $ OMap.toMap $ getArgs op