module Beng.Interpret (
	interpret
) where

import Utils.Fallible
import Utils.Fallible.Trans

import Beng.Build (buildFile)
import Beng.Errors (printError)
import Beng.Run (run)

interpret :: FilePath -> VoidFallible
interpret path = do
	ops <- buildFile path
	let interpret' = \case
		[] -> success
		nextOp:remainingOps -> do
			result <- falT $ mapError printError $ run nextOp
			-- TODO: Simply printing the result is (obviously) a placeholder.
			tryIO $ putStrLn $ show result
			interpret' remainingOps	
	interpret' ops.l