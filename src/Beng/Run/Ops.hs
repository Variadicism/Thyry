module Beng.Run.Ops (
	runArg,
	run
) where

import Utils.Fallible hiding (Fallible)
import qualified Utils.Populace as P

import Beng.Parse.Matches (Capture(..))
import Beng.Run.Types.Data (Data)
import Beng.Run.Values (Value(..))
import Beng.Ops (Op(..), getArgs)
import Beng.Errors (Error(UndefinedError), Fallible)
import Beng.Types.Ops.Definitions (Definition(..))

import qualified Data.Map.Ordered as OMap

runArg :: Capture -> Fallible Value
runArg = \case
	OpCapture op -> do
		dataOut <- run op
		return $ DataValue dataOut
	StringCapture text -> return $ StringValue text
	ListCapture{captures} -> fmap ListValue $ sequence $ P.map runArg captures
	MaybeCapture{maybeCapture} -> case maybeCapture of
		Nothing -> return $ MaybeValue Nothing
		Just capture -> fmap (MaybeValue . Just) $ runArg capture

run :: Op -> Fallible Data
run op = case op.card.definition of
	Nothing -> Error $ UndefinedError (show op) op
	Just definition -> definition.runWith $ OMap.toMap $ getArgs op