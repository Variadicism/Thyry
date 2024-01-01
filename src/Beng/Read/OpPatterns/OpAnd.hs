module Beng.Read.OpPatterns.OpAnd (
	readAllMatches
) where

import Utils.Lists (showWithAnd)
import Utils.Messaging (debugM, msg)
import Utils.Readers (MultiReader)
import Utils.Tuples (mapFst2)

import {-# SOURCE #-} qualified Beng.Read.OpPatterns as OpPattern
import Beng.Types.OpPatterns (OpPattern)

import Data.Char (isAlphaNum)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

readAllMatches :: [OpPattern] -> Bool -> MultiReader Text
readAllMatches subpatterns wordPrecedes = \toParse -> do
	debugM $ "Attempting to read " ++ (showWithAnd $ map show subpatterns) ++ " from " ++ msg toParse ++ "..."
	case subpatterns of
		[] -> [("", toParse)]
		(nextSubpattern:remainingSubpatterns) -> do
			let matches = OpPattern.readAllMatches nextSubpattern wordPrecedes toParse
			let readAllMatchesFrom (parsed, toParse) = do
				let wordPrecedes = isAlphaNum $ Text.last parsed
				let matches = readAllMatches remainingSubpatterns wordPrecedes toParse
				map (mapFst2 \m -> Text.concat [parsed, m]) matches
			concatMap readAllMatchesFrom matches