module Beng.Interpret (
	interpret
) where

import Utils.Monads

import Beng.Build (buildFile)
import Beng.Run.Ops (evaluate)

interpret :: FilePath -> VoidFallible
interpret path = do
	ops <- buildFile path
	let interpret' = \case
		[] -> success
		nextOp:remainingOps -> do
			result <- falT $ evaluate nextOp
			-- TODO: Simply printing the result is (obviously) a placeholder.
			tryIO $ putStrLn $ show result
			interpret' remainingOps	
	interpret' ops