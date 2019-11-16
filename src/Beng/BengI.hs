{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}

module Main where

import Utils.Errors
import Utils.Messaging
import Utils.Monads

import Beng.Read.OpPatterns
import Beng.Read.Ops
import Beng.Read.ReadingOps
import Beng.StandardOps (standardOps)

import Data.List (intercalate)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text (dropEnd, isSuffixOf, null)
import Data.Text.Lazy.IO (hGetContents)

import System.Environment (getArgs)
import System.IO (IOMode(ReadMode), hPutStrLn, openFile, stderr)

interpret :: Text -> VoidFallible
interpret code = do
	opsRead <- falT $ readCode standardOps code
	let interpret' opsToRun = do
		if null opsToRun
			then void
		else do
			let result = runOp $ head opsToRun
			putStrLn $ show result
			interpret' $ tail opsToRun	
	mFal $ interpret' opsRead

readAndInterpret :: FilePath -> VoidFallible
readAndInterpret bengFilePath = do
	bengFile <- tryIO $ openFile bengFilePath ReadMode
	bengCode <- tryIO $ hGetContents bengFile
	let bengCodeWithoutTrailingWhitespace =
		if "\n" `Text.isSuffixOf` bengCode then Text.dropEnd 1 bengCode else bengCode
	interpret bengCodeWithoutTrailingWhitespace

main = doFallibleMain $ do
	args <- tryIO getArgs
	debugM "Checking args..."
	if length args /= 1
		then falT $ toError "This program expects exactly one argument: the file to interpret."
		else do
			debugM "Command arguments accepted"
			readAndInterpret $ head args
