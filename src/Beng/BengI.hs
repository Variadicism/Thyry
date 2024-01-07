module Main where

import Utils.Errors
import Utils.Messaging
import Utils.Monads

import Beng.Interpret (interpret)

import System.Environment (getArgs)

main = doFallibleMain $ do
	args <- tryIO getArgs
	debugM "Checking args..."
	case args of
		[path] -> do
			debugM "Command arguments accepted"
			interpret path
		_ -> falT $ toError "This program expects exactly one argument: the file to interpret."