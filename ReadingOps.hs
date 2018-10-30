module ReadingOps (
	readOp
) where

import Utils.Errors
import Utils.Messaging
import Utils.Readers

import Ops
import OpPatterns

import Data.List (find, intercalate)
import Data.Map (Map)
import qualified Data.Map as Map (empty, fromList, insert, size)
import Data.Map.Ordered (OMap, (<|))
import qualified Data.Map.Ordered as OMap (assocs, elemAt, null, size)
import Data.Text (Text)
import Data.Text.Lazy.Read (Reader)

parseTheNextArgAndSuffix :: OpArg -> OpPattern -> [OpDefinition] -> OpDefinition -> Map String Op -> MultiReader Op
parseTheNextArgAndSuffix opArg nextSuffix context definition argsRead = \toParse -> do
	(opRead, afterOp) <- readOp context toParse
	let newArgsRead = Map.insert (argName opArg) opRead argsRead
	readArgsAndSuffixes context definition newArgsRead nextSuffix afterOp

readArgsAndSuffixes :: [OpDefinition] -> OpDefinition -> Map String Op -> OpPattern -> MultiReader Op
readArgsAndSuffixes context definition argsRead nextPattern toParse = do
	let allNextPatternMatches = readAllMatches nextPattern toParse
	let readRemainingArgsAndSuffixes (_, remainder) =
		case argsAndSuffixes definition `OMap.elemAt` Map.size argsRead of
			Just (opArg, nextSuffix) -> parseTheNextArgAndSuffix opArg nextSuffix context definition argsRead remainder
			Nothing ->  -- All args and suffixes were parsed!
				return $ (Op {
					opDefinition = definition,
					argValues = argsRead }, remainder)
	concat $ map readRemainingArgsAndSuffixes allNextPatternMatches

readNonPrefixedOp :: [OpDefinition] -> Op -> MultiReader Op
readNonPrefixedOp context firstArgument = \toParse -> do
	let readNonPrefixedOp' remainingNonPrefixedDefs =
		if null remainingNonPrefixedDefs
			then []
		else do
			let nextDef = head remainingNonPrefixedDefs
			let (firstOpArgDef, firstSuffix) = head $ OMap.assocs $ argsAndSuffixes nextDef
			let argsReadFirst = Map.fromList [(argName firstOpArgDef, firstArgument)]
			let opReadResults = readArgsAndSuffixes context nextDef argsReadFirst firstSuffix toParse
			debugM (if null opReadResults
					then "Attempting to parse the non-prefixed op " ++ msgShow nextDef ++ " failed."
					else "Non-prefixed ops were successfully read " ++ (show $ length opReadResults) ++ " way(s).")
			opReadResults ++ (readNonPrefixedOp' $ tail remainingNonPrefixedDefs)
	readNonPrefixedOp' $ filter (not . hasPrefix) context

readPrefixedOp :: [OpDefinition] -> MultiReader Op
readPrefixedOp context = \toParse -> do
	let readPrefixedOp' remainingPrefixedDefs =
		if null remainingPrefixedDefs
			then []
		else do
			let nextDef = head remainingPrefixedDefs
			let opReadResults = readArgsAndSuffixes context nextDef Map.empty (opPrefix nextDef) toParse
			debugM (if null opReadResults
					then "Attempting to parse the prefixed op " ++ msgShow nextDef ++ " failed."
					else "Prefixed ops were successfully read " ++ (show $ length opReadResults) ++ " ways(s).")
			opReadResults ++ (readPrefixedOp' $ tail remainingPrefixedDefs)
	readPrefixedOp' $ filter hasPrefix context

readOp :: [OpDefinition] -> MultiReader Op
readOp context = \toParse -> do
	-- First, we must read an op that has a prefix -- any kind of content before an argument.
	let allPrefixedOpMatches = readPrefixedOp context toParse
	-- After that, we can try reading ops without prefixes to see if one uses the first op as its first argument.
	-- Remember that this is recursive because an op without a prefix can take as its first argument an op without a prefix that takes as its first argument an op without a prefix... indefinitely.
	let readEnclosingOpOrUseFirstOp enclosedOpResults@(opRead, afterReadOp) = do
		let enclosingOpReadResults = readNonPrefixedOp context opRead afterReadOp
		if null enclosingOpReadResults then
			debug "No enclosing op was found." $
			[enclosedOpResults]
		else
			debug ((show $ length enclosingOpReadResults) ++ " possible enclosing ops were found.") $
			[enclosedOpResults] ++ (concat $ map readEnclosingOpOrUseFirstOp enclosingOpReadResults)
	concat $ map readEnclosingOpOrUseFirstOp allPrefixedOpMatches
