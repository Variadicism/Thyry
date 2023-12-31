module Beng.Read.OpPatterns.OpDelimited (
	readAllMatches
) where

import Utils.Messaging (debugM, msg, msgShow)
import Utils.Readers (MultiReader)
import Utils.Tuples (mapFst2)

import {-# SOURCE #-} qualified Beng.Read.OpPatterns as OpPattern
import Beng.Types.OpPatterns (OpPattern)

import Data.Char (isAlphaNum)
import Data.Text.Lazy (Text, pack)
import qualified Data.Text.Lazy as Text

-- private

parseTail :: String -> OpPattern -> MultiReader Text
parseTail delimiter delimitend = \toParse ->
	if pack delimiter `Text.isPrefixOf` toParse then do
		let wordPrecedesDelimitend = isAlphaNum $ last delimiter
		readAllMatches delimiter delimitend wordPrecedesDelimitend $
			Text.drop (fromIntegral $ length delimiter) toParse
	else []

parseFromHead :: String -> OpPattern -> (Text, Text) -> [(Text, Text)]
parseFromHead delimiter delimitend group1Match@(group1MatchText, toParse) = do
	let tailParses = parseTail delimiter delimitend toParse
	let addGroup1AndDelimiter = \t -> Text.concat [group1MatchText, pack delimiter, t]
	let groupNMatches = map (mapFst2 addGroup1AndDelimiter) tailParses
	group1Match:groupNMatches

-- exported

readAllMatches :: String -> OpPattern -> Bool -> MultiReader Text
-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me!
readAllMatches delimiter delimitend wordPrecedes = \toParse -> do
	debugM $ "Attempting to read " ++ msg delimiter ++
		" delimited by " ++ msgShow delimitend ++ " from " ++ msg toParse ++ "..."
	let group1Matches = OpPattern.readAllMatches delimitend wordPrecedes toParse
	concatMap (parseFromHead delimiter delimitend) group1Matches