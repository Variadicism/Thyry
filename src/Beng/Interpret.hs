module Beng.Interpret (
	interpret
) where

import Utils.Monads

import Beng.Parse (parseFile)
import Beng.Run.Ops (run)

interpret :: FilePath -> VoidFallible
interpret path = do
	ops <- parseFile path
	let interpret' = \case
		[] -> return ()
		nextOp:remainingOps -> do
			let result = run nextOp
			-- TODO: Simply printing the result is (obviously) a placeholder.
			putStrLn $ show result
			interpret' remainingOps	
	mFal $ interpret' ops