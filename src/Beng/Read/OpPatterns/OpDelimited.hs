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

readAllMatches :: String -> OpPattern -> Bool -> MultiReader Text
-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me!
readAllMatches delimiter delimitend wordPrecedes = \toParse -> do
	debugM $ "Attempting to read " ++ msg delimiter ++
		" delimited by " ++ msgShow delimitend ++ " from " ++ msg toParse ++ "..."
	let group1Matches = OpPattern.readAllMatches delimitend wordPrecedes toParse
	let parseDelimiterAndMore = \toParse' -> do
		if (pack delimiter) `Text.isPrefixOf` toParse' then do
			let wordPrecedes' = isAlphaNum $ last delimiter
			readAllMatches delimiter delimitend wordPrecedes' $
				Text.drop (fromIntegral $ length delimiter) toParse'
		else
			[]
	let parseDelimitedGroups = \group1Match@(group1MatchText, afterGroup1) -> do
		let afterGroup1DelimitedParses = parseDelimiterAndMore afterGroup1
		let addGroup1AndDelimiter = \t -> Text.concat [group1MatchText, pack delimiter, t]
		let groupNMatches = map (mapFst2 addGroup1AndDelimiter) afterGroup1DelimitedParses
		group1Match:groupNMatches
	concat $ map parseDelimitedGroups group1Matches