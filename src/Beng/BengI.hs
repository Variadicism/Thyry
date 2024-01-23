module Main where

import Utils.Fallible
import Utils.Fallible.Trans
import Utils.Messaging

import Beng.Interpret (interpret)

import System.Environment (getArgs)

main = doFallibleMain $ do
	args <- tryIO getArgs
	debugM "Checking args..."
	case args of
		[path] -> do
			debugM "Command arguments accepted"
			interpret path
		_ -> falT $ Error "This program expects exactly one argument: the file to interpret."