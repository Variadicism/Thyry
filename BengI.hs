module Main where

import Utils.Errors
import Utils.Lists
import Utils.Messaging
import Utils.Monads

import Ops
import ReadingOps

import Data.Map ((!))
import Data.Map.Ordered as OMap (empty, fromList)
import Data.Text.Lazy (Text, pack)
import qualified Data.Text.Lazy as Text (dropEnd, isSuffixOf, null)
import Data.Text.Lazy.IO (hGetContents)

import System.Environment (getArgs)
import System.IO (IOMode(ReadMode), hPutStrLn, openFile, stderr)

knownOps :: [OpDefinition]
knownOps = [
	OpDefinition { opPrefix = "2", argsAndSuffixes = OMap.empty, runOpWith = const 2 },
	OpDefinition { opPrefix = "3", argsAndSuffixes = OMap.empty, runOpWith = const 3 },
	OpDefinition { opPrefix = "", argsAndSuffixes = OMap.fromList [
			(OpArg { argName = "Augend" }, "+"),
			(OpArg { argName = "Addend" }, "")],
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
		if (pack "\n") `Text.isSuffixOf` bengCode then Text.dropEnd 1 bengCode else bengCode
	interpret bengCodeWithoutTrailingWhitespace

main = doFallibleMain $ do
	args <- tryIO getArgs
	debug "Checking args..." $ if length args /= 1
		then tryIO $ hPutStrLn stderr "This program expects exactly one argument: the file to interpret."
		else
			debug "Command arguments accepted" $
			readAndInterpret $ head args
