module Beng.Read.OpPatterns.OpAnd (
	readAllMatches
) where

import Utils.Lists (showWithAnd)
import Utils.Messaging (debugM, msg)
import Utils.Readers (MultiReader)

import {-# SOURCE #-} qualified Beng.Read.OpPatterns as OpPattern
import Beng.Types.OpPatterns (OpPattern)

import Data.Char (isAlphaNum)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text
import GHC.Int (Int64)

-- private

readAllMatches' :: [OpPattern] -> Bool -> Int64 -> MultiReader Text
readAllMatches' subpatterns wordPrecedes charsReadSoFar = \toParse ->
	case subpatterns of
		[] -> [Text.splitAt charsReadSoFar toParse]
		(nextSubpattern:remainingSubpatterns) -> do
			let toParseRemaining = Text.drop charsReadSoFar toParse
			let matches = OpPattern.readAllMatches nextSubpattern wordPrecedes toParseRemaining
			let readAllMatchesFrom (parsed, toParse) = readAllMatches' remainingSubpatterns
				(isAlphaNum $ Text.last parsed) (charsReadSoFar + Text.length parsed) toParse
			concat $ map readAllMatchesFrom matches

-- exported

readAllMatches :: [OpPattern] -> Bool -> MultiReader Text
readAllMatches subpatterns wordPrecedes = \toParse -> do
	debugM $ "Attempting to read " ++ (showWithAnd $ map show subpatterns) ++ " from " ++ msg toParse ++ "..."
	readAllMatches' subpatterns wordPrecedes 0 toParse