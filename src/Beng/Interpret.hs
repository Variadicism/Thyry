module Beng.Interpret (
	interpret
) where

import Utils.Fallible
import Utils.Fallible.Trans

import Beng.Build (buildFile)
import Beng.Errors (printError)
import Beng.Run (run)
import Beng.Values (Value(OpValue))

interpret :: FilePath -> VoidFallible
interpret path = do
	ops <- buildFile path
	let interpret' = \case
		[] -> success
		nextOp:remainingOps -> do
			let runOpsDeep op = run op >>= \case
				OpValue nextOp -> runOpsDeep nextOp
				value -> return value
			result <- falT $ mapError printError $ runOpsDeep nextOp
			-- TODO: Simply printing the result is (obviously) a placeholder.
			tryIO $ putStrLn $ show result
			interpret' remainingOps	
	interpret' ops.l