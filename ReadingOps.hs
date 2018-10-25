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

parseTheNextArgAndSuffix :: OpArg -> OpPattern -> [OpDefinition] -> OpDefinition -> Map String Op -> Reader Op
parseTheNextArgAndSuffix opArg nextSuffix context definition argsRead = \toParse -> do
	(opRead, afterOp) <- readOp context toParse
	let newArgsRead = Map.insert (argName opArg) opRead argsRead
	readArgsAndSuffixes context definition newArgsRead nextSuffix afterOp

readArgsAndSuffixes :: [OpDefinition] -> OpDefinition -> Map String Op -> OpPattern -> Reader Op
readArgsAndSuffixes context definition argsRead nextPattern = \toParse -> do
	(_, remainder) <- readAllMatches nextPattern toParse
	case argsAndSuffixes definition `OMap.elemAt` Map.size argsRead of
		Just (opArg, nextSuffix) -> parseTheNextArgAndSuffix opArg nextSuffix context definition argsRead remainder
		Nothing ->  -- All args and suffixes were parsed!
			return $ (Op {
				opDefinition = definition,
				argValues = argsRead }, remainder)

readNonPrefixedOp :: [OpDefinition] -> Op -> Reader Op
readNonPrefixedOp context firstArgument = \toParse -> do
	let readNonPrefixedOp' = \remainingNonPrefixedDefs ->
		if null remainingNonPrefixedDefs
			then toError $ "No non-prefixed op could be found at " ++ msg toParse ++ "!"
			else do
				let nextDef = head remainingNonPrefixedDefs
				let (firstOpArgDef, firstSuffix) = head $ OMap.assocs $ argsAndSuffixes nextDef
				let argsReadFirst = Map.fromList [(argName firstOpArgDef, firstArgument)]
				let errorOrOpReadResults = readArgsAndSuffixes context nextDef argsReadFirst firstSuffix toParse
				case errorOrOpReadResults of
					Left error ->
						debug ("Attempting to parse the non-prefixed op " ++ msgShow nextDef ++ " failed: " ++ error) $
						readNonPrefixedOp' $ tail remainingNonPrefixedDefs
					Right opReadResults@(opRead, _) ->
						debug ("Successfully read non-prefixed op: " ++ msgShow opRead) $
						return opReadResults
	readNonPrefixedOp' $ filter (not . hasPrefix) context

readPrefixedOp :: [OpDefinition] -> Reader Op
readPrefixedOp context = \toParse -> do
	let readPrefixedOp' = \remainingPrefixedDefs ->
		if null remainingPrefixedDefs then do
			let noPrefixedOpError = "No prefixed op could be found at " ++ msg toParse ++ "!"
			debugM noPrefixedOpError
			toError noPrefixedOpError
		else do
			let nextDef = head remainingPrefixedDefs
			let errorOrOpReadResults = readArgsAndSuffixes context nextDef Map.empty (opPrefix nextDef) toParse
			case errorOrOpReadResults of
				Left error ->
					debug ("Attempting to parse the prefixed op " ++ msgShow nextDef ++ " failed: " ++ error) $
					readPrefixedOp' $ tail remainingPrefixedDefs
				Right opReadResults@(opRead, _) ->
					debug ("The prefixed op \"" ++ show opRead ++ "\" was parsed successfully!") $
					return opReadResults
	readPrefixedOp' $ filter hasPrefix context

readOp :: [OpDefinition] -> Reader Op
readOp context = \toParse -> do
	-- First, we must read an op that has a prefix -- any kind of content before an argument.
	(firstOp, afterFirstOp) <- readPrefixedOp context toParse
	-- After that, we can try reading ops without prefixes to see if one uses the first op as its first argument.
	-- Remember that this is recursive because an op without a prefix can take as its first argument an op without a prefix that takes as its first argument an op without a prefix... indefinitely.
	let readEnclosingOpOrUseFirstOp = \readOp afterReadOp -> do
		let errorOrEnclosingOpReadResults = readNonPrefixedOp context readOp afterReadOp
		case errorOrEnclosingOpReadResults of
			Left error ->
				debug ("No enclosing op was found: " ++ error) $
				(readOp, afterReadOp)
			Right (enclosingOp, afterEnclosingOp) -> readEnclosingOpOrUseFirstOp enclosingOp afterEnclosingOp
	fallible $ readEnclosingOpOrUseFirstOp firstOp afterFirstOp
