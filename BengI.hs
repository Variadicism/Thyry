{-# LANGUAGE OverloadedStrings #-}

module Main where

import Utils.Errors
import Utils.Lists
import Utils.Messaging
import Utils.Monads

import OpPatterns
import Ops
import ReadingOps

import Data.Map ((!))
import Data.Map.Ordered as OMap (empty, fromList)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text (dropEnd, isSuffixOf, null)
import Data.Text.Lazy.IO (hGetContents)

import System.Environment (getArgs)
import System.IO (IOMode(ReadMode), hPutStrLn, openFile, stderr)

knownOps :: [OpDefinition]
knownOps = [
	OpDefinition { opPrefix = OpLiteral "2", argsAndSuffixes = OMap.empty, runOpWith = const 2 },
	OpDefinition { opPrefix = OpLiteral "3", argsAndSuffixes = OMap.empty, runOpWith = const 3 },
	OpDefinition { opPrefix = OpEmpty, argsAndSuffixes = OMap.fromList [
			(OpArg { argName = "Augend" }, OpLiteral "+"),
			(OpArg { argName = "Addend" }, OpEmpty)],
		runOpWith = \args -> args ! "Augend" + args ! "Addend" }]

readCode :: Text -> Fallible [Op]
readCode code = do
	let readCode' = \code' previousOps ->
		if Text.null code' then
			fallible []
		else do
			(opRead, remainingCode) <- readOp knownOps code'
			remainingOpsRead <- readCode remainingCode
			fallible $ previousOps ++ [opRead] ++ remainingOpsRead
	readCode' code []

interpret :: Text -> VoidFallible
interpret code = do
	opsRead <- falT $ readCode code
	let interpret' = \opsToRun -> do
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
		else
			debug "Command arguments accepted" $
			readAndInterpret $ head args
