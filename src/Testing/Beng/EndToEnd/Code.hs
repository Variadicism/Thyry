module Testing.Beng.EndToEnd.Code (
	makeCodeTests
) where

import Utils.Testing

import Testing.Beng.Utils.EndToEnd (
	assertFileErrors,
	assertFileReturns,
	assertFinalInt)

import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>), makeRelative)
import Data.List (isPrefixOf, partition, sort)

discoverFilesRecursively :: FilePath -> IO [FilePath]
discoverFilesRecursively root = do
	children <- listDirectory root
	let childPaths = map (root </>) children
	nestedPaths <- traverse
		(\path -> do
			isDirectory <- doesDirectoryExist path
			if isDirectory then
				discoverFilesRecursively path
			else
				return [path])
		childPaths
	return $ concat nestedPaths

makeCodeTests :: IO TestCategory
makeCodeTests = do
	inputPaths <- discoverFilesRecursively "test input"
	let (errorPaths, successPaths) = partition ("test input/errors" `isPrefixOf`) $ sort inputPaths
	return $ TestCategories "builtin code" [
		PureTests "if" [
			("false branch in DefineValue scope",
				assertFinalInt 10 "Y := 5\nN := 10\nif no, Y\nelse N"),
			("true branch in DefineValue scope",
				assertFinalInt 5 "Y := 5\nN := 10\nif yes, Y\nelse N") ],
		PureTests "lazy" [
			("First of Only is forced by addition",
				assertFinalInt 11 "First of only 3 + 8") ],
		IOTests "fixture success" $
			flip map successPaths
				\path -> (makeRelative "test input" path, assertFileReturns path),
		IOTests "fixture error" $
			flip map errorPaths
				\path -> (makeRelative "test input" path, assertFileErrors path) ]
