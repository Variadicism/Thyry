{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}

module Main where

import Utils.Errors
import Utils.Lists
import Utils.Messaging
import Utils.Monads

import Beng.Read.OpPatterns
import Beng.Read.Ops
import Beng.Read.ReadingOps

import Data.List (intercalate)
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
			(OpArg { argName = "Augend" }, OpAnd [OpSpace, OpLiteral "+", OpSpace]),
			(OpArg { argName = "Addend" }, OpEmpty)],
		runOpWith = \args -> args ! "Augend" + args ! "Addend" }]

readCodePossibilities :: Text -> [Op] -> [[Op]]
readCodePossibilities "" previousOps = [previousOps]
readCodePossibilities code previousOps = do
	let opReadResults = readOp knownOps code
	let readRemainingCode (opRead, remainingCode) = readCodePossibilities remainingCode (previousOps ++ [opRead])
	concat $ map readRemainingCode opReadResults

readCode :: Text -> Fallible [Op]
readCode code = do
	let readPossibilities = readCodePossibilities code []
	if null readPossibilities then
		toError $ "There was a problem parsing this Beng code!"
	else if length readPossibilities >= 2 then
		toError $ "This Beng code is ambiguous! " ++ (show $ length readPossibilities) ++ " ways were found to parse it:\n" ++ (intercalate (wrap "\n" $ replicate 20 '#') $ map (intercalate "\n" . map showOpParens) readPossibilities)
	else
		fallible $ head readPossibilities

interpret :: Text -> VoidFallible
interpret code = do
	opsRead <- falT $ readCode code
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
		else
			debug "Command arguments accepted" $
			readAndInterpret $ head args
