module Beng.Read.OpPatterns.OpDelimited (
	readAllMatches
) where

import Utils.Messaging (debugM, msg, msgShow)
import Utils.Readers (MultiReader)
import Utils.Tuples (mapFst2)

import {-# SOURCE #-} qualified Beng.Read.OpPatterns as OpPattern
import Beng.Types.OpPatterns (OpPattern)

import Data.Char (isAlphaNum)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

-- private

parseFromPrevious :: (Bool -> MultiReader Text) -> (Text, Text) -> [(Text, Text)]
parseFromPrevious reader (previousMatch, toParse) = do
	let wordPrecedes = isAlphaNum $ Text.last previousMatch
	let matches = reader wordPrecedes toParse
	let prependPreviousMatch nextMatch = Text.concat [previousMatch, nextMatch]
	map (mapFst2 prependPreviousMatch) matches

parseTail :: OpPattern -> OpPattern -> Bool -> MultiReader Text
parseTail delimiter delimitend wordPrecedes = \toParse -> do
	let delimiterParses = OpPattern.readAllMatches delimiter wordPrecedes toParse
	concatMap (parseFromPrevious $ readAllMatches delimiter delimitend) delimiterParses

-- exported

readAllMatches :: OpPattern -> OpPattern -> Bool -> MultiReader Text
-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me!
readAllMatches delimiter delimitend wordPrecedes = \toParse -> do
	debugM $ "Attempting to read " ++ msgShow delimiter ++
		" delimited by " ++ msgShow delimitend ++ " from " ++ msg toParse ++ "..."
	let group1Matches = OpPattern.readAllMatches delimitend wordPrecedes toParse
	let groupNMatches = concatMap (parseFromPrevious $ parseTail delimiter delimitend) group1Matches
	group1Matches ++ groupNMatches