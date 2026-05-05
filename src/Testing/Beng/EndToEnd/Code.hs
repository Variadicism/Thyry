module Testing.Beng.EndToEnd.Code (
	testEndToEndCode
) where

import Utils.Testing

import Testing.Beng.Utils.EndToEnd (
	assertFileErrors,
	assertFileReturns,
	assertFinalInt)

import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>), makeRelative)
import System.IO.Unsafe (unsafePerformIO)
import Data.List (isPrefixOf, sort)

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

fixtureSuccesses :: [(String, FilePath)]
fixtureSuccesses = unsafePerformIO do
	paths <- discoverFilesRecursively "test input"
	let successPaths = filter (not . isPrefixOf "test input/errors") paths
	let sortedPaths = sort successPaths
	return $ map (\path -> (makeRelative "test input" path, path)) sortedPaths

fixtureErrors :: [(String, FilePath)]
fixtureErrors = unsafePerformIO do
	paths <- discoverFilesRecursively "test input/errors"
	let sortedPaths = sort paths
	return $ map (\path -> (makeRelative "test input" path, path)) sortedPaths

testEndToEndCode :: TestCategory
testEndToEndCode = TestCategories "builtin code" [
	PureTests "if" [
		("false branch in DefineValue scope",
			assertFinalInt 10 "Y := 5\nN := 10\nif no, Y\nelse N"),
		("true branch in DefineValue scope",
			assertFinalInt 5 "Y := 5\nN := 10\nif yes, Y\nelse N") ],
	PureTests "lazy" [
		("First of Only is forced by addition",
			assertFinalInt 11 "First of only 3 + 8") ],
	IOTests "fixture successes" $
		map (\(name, path) -> (name, assertFileReturns path)) fixtureSuccesses,
	IOTests "fixture errors" $
		map (\(name, path) -> (name, assertFileErrors path)) fixtureErrors ]
