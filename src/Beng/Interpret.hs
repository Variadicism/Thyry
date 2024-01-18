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
		[] -> return ()
		nextOp:remainingOps -> do
			let result = evaluate nextOp
			-- TODO: Simply printing the result is (obviously) a placeholder.
			putStrLn $ show result
			interpret' remainingOps	
	mFal $ interpret' ops