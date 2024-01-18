module Beng.Run.Ops (
	runAs,
	evaluate
) where

import Utils.Errors

import Beng.Parse.Matches (Capture(..))
import qualified Beng.Parse.Patterns as Pattern
import Beng.Run.Values (Data, Value(..), ValueType(..))
import Beng.Ops (Op(..), getArgs)
import Beng.Types.Ops.Declarations (Declaration(..))
import Beng.Types.Ops.Definitions (Definition(..))

import qualified Data.Map as Map
import Data.Map (Map)
import qualified Data.Map.Ordered as OMap
import Data.Map.Ordered (OMap)

runAs :: ValueType -> Capture -> Fallible Value
runAs valueType capture = case (valueType, capture) of
	(ListType{element}, ListCapture{captures}) ->
		fmap ListValue $ reduceErrors $ map (runAs element) captures
	(MaybeType{inner}, MaybeCapture{maybeCapture}) -> case maybeCapture of
		Nothing -> return $ MaybeValue Nothing
		Just capture -> fmap (MaybeValue . Just) $ runAs inner capture
	(DataType, OpCapture op) -> case op.card.definition of
		Nothing -> toError $ show op.card.declaration ++ " cannot be run without being defined!"
		Just definition -> do
			let opArgs = Pattern.getArgs definition.declaration.pattern
			let runArgEntry :: (String, Capture) -> Fallible (String, Value) = \(name, capture) -> do
				let (Just argValueType) = OMap.lookup name opArgs
				fmap (name,) $ runAs argValueType capture
			let runArgs :: (OMap String Capture -> Fallible (Map String Value)) =
				fmap Map.fromList . reduceErrors . map runArgEntry . OMap.assocs

			argValues <- runArgs $ getArgs op
			runData <- definition.runWith argValues
			return $ DataValue runData
	(OpType, OpCapture op) -> return $ OpValue op
	-- PreOps are already made into OpValues in the build step.
	(PreOpType, OpCapture op) -> return $ OpValue op
	_ -> error $ show capture ++ " was expected to be of type " ++ show valueType ++ "!"

evaluate :: Op -> Fallible Data
evaluate op = do
	DataValue dataValue <- runAs DataType $ OpCapture op
	return dataValue