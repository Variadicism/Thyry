{-# LANGUAGE OverloadedStrings #-}

module Beng.Read.ReadingOps (
	readOp,
	readCode,
	standardOps
) where

import Utils.Errors
import Utils.Lists
import Utils.Messaging
import Utils.Readers

import Beng.Read.Ops
import Beng.Read.OpPatterns
import Beng.StandardOps (standardOps)

import Data.Char (isAlphaNum)
import Data.List (find, intercalate)
import Data.Map (Map, (!))
import qualified Data.Map as Map (empty, fromList, insert, size)
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap (assocs, elemAt, fromList, null, size)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text (index, last, length)

parseTheNextArgAndSuffix :: OpArg -> OpPattern -> [OpDefinition] -> OpDefinition -> Map String Op -> Bool -> MultiReader Op
parseTheNextArgAndSuffix opArg nextSuffix context definition argsRead prevCharIsAlphanum = \toParse -> do
	(opRead, afterOp) <- readOp context toParse
	let newArgsRead = Map.insert (argName opArg) opRead argsRead
	let stringReadLength = Text.length toParse - Text.length afterOp
	let lastCharReadIsAlphanum = isAlphaNum $ Text.index toParse stringReadLength
	readArgsAndSuffixes context definition newArgsRead nextSuffix lastCharReadIsAlphanum afterOp

readArgsAndSuffixes :: [OpDefinition] -> OpDefinition -> Map String Op -> OpPattern -> Bool -> MultiReader Op
readArgsAndSuffixes context definition argsRead nextPattern prevCharIsAlphanum toParse = do
	let allNextPatternMatches = readAllMatches nextPattern prevCharIsAlphanum toParse
	let readRemainingArgsAndSuffixes (textRead, remainder) =
		case argsAndSuffixes definition `OMap.elemAt` Map.size argsRead of
			Just (opArg, nextSuffix) -> parseTheNextArgAndSuffix opArg nextSuffix context definition argsRead (isAlphaNum $ Text.last textRead) remainder
			Nothing ->  -- All args and suffixes were parsed!
				return $ (Op {
					opDefinition = definition,
					argValues = argsRead }, remainder)
	concat $ map readRemainingArgsAndSuffixes allNextPatternMatches

readNonPrefixedOp :: [OpDefinition] -> Op -> Bool -> MultiReader Op
readNonPrefixedOp context firstArgument prevCharIsAlphanum = \toParse -> do
	let readNonPrefixedOp' remainingNonPrefixedDefs =
		if null remainingNonPrefixedDefs
			then []
		else do
			let nextDef = head remainingNonPrefixedDefs
			let (firstOpArgDef, firstSuffix) = head $ OMap.assocs $ argsAndSuffixes nextDef
			let argsReadFirst = Map.fromList [(argName firstOpArgDef, firstArgument)]
			let opReadResults = readArgsAndSuffixes context nextDef argsReadFirst firstSuffix prevCharIsAlphanum toParse
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
			let opReadResults = readArgsAndSuffixes context nextDef Map.empty (opPrefix nextDef) False toParse
			debugM (if null opReadResults
					then "Attempting to parse the prefixed op " ++ msgShow nextDef ++ " failed."
					else "Prefixed ops were successfully read " ++ (show $ length opReadResults) ++ " way(s).")
			opReadResults ++ (readPrefixedOp' $ tail remainingPrefixedDefs)
	readPrefixedOp' $ filter hasPrefix context

readOp :: [OpDefinition] -> MultiReader Op
readOp context = \toParse -> do
	-- First, we must read an op that has a prefix -- any kind of content before an argument.
	let allPrefixedOpMatches = readPrefixedOp context toParse
	-- After that, we can try reading ops without prefixes to see if one uses the first op as its first argument.
	-- Remember that this is recursive because an op without a prefix can take as its first argument an op without a prefix that takes as its first argument an op without a prefix... indefinitely.
	let readEnclosingOpOrUseFirstOp enclosedOpResults@(opRead, afterReadOp) = do
		let opReadEndsWithAlphanum = isAlphaNum $ Text.index toParse (Text.length toParse - Text.length afterReadOp - 1)
		let enclosingOpReadResults = readNonPrefixedOp context opRead opReadEndsWithAlphanum afterReadOp
		if null enclosingOpReadResults then do
			debugM "No enclosing op was found."
			[enclosedOpResults]
		else do
			debugM $ msgShow opRead ++ " can be enclosed " ++ (show $ length enclosingOpReadResults) ++ " way(s)."
			[enclosedOpResults] ++ (concat $ map readEnclosingOpOrUseFirstOp enclosingOpReadResults)
	concat $ map readEnclosingOpOrUseFirstOp allPrefixedOpMatches

-- TODO: refactor this to return [Fallible [Op]] to give helpful errors when parsing fails.
readCodePossibilities :: Text -> [OpDefinition] -> [[Op]]
readCodePossibilities code context = do
	let readCodePossibilities' code' previousOps =
		if code' == "" then
			[previousOps]
		else do
			let opReadResults = readOp context code'
			let readRemainingCode (opRead, remainingCode) = readCodePossibilities' remainingCode (previousOps ++ [opRead])
			concat $ map readRemainingCode opReadResults
	readCodePossibilities' code []

readCode :: Text -> Fallible [Op]
readCode code = do
	let readPossibilities = readCodePossibilities code standardOps
	if null readPossibilities then
		toError "There was a problem parsing this Beng code!"
	else do
		if (length readPossibilities >= 2) then
			debugM ("This Beng code is ambiguous! " ++ (show $ length readPossibilities) ++ " ways were found to parse it:\n" ++ (intercalate (wrap "\n" $ replicate 20 '#') $ map (intercalate "\n" . map showOpParens) readPossibilities))
		else return ()
		fallible $ head readPossibilities

