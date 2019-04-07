{-# LANGUAGE InstanceSigs, OverloadedStrings #-}

module Beng.Read.OpPatterns (
	OpPattern(..),
	readAllMatches
) where

import Utils.Errors
import Utils.Lists
import Utils.Messaging

import Data.Char (isAlphaNum, isSpace)
import Data.Text.Lazy (Text, pack, unpack)
import qualified Data.Text.Lazy as Text (drop, head, index, isPrefixOf, last, length, splitAt, takeWhile)

data OpPattern = OpEmpty | OpSpace | OpLiteral Text | OpAnd [OpPattern] | OpDelimited String OpPattern

-- In the future, the Maybe will become a list so that all possible matches can be given and the tuple at the end will include capturing group data (Map String String).
readAllMatches ::
	OpPattern ->  -- ^ The OpPattern to attempt to parse from the beginning of some text
	Bool ->       -- ^ The previous character exists (i.e., not the beginning of a code stream) and is an alphanumeric character
	Text ->       -- ^ The text to attempt to parse the given OpPattern
	[(Text, Text)]    -- ^ For each possible way for the given OpPattern to match the start of the given Text, (The text matched to the given OpPattern, the text remaining after parsing) or an error if the given OpPattern was not matched at the beginning of the given Text
-- OpEmpty
readAllMatches OpEmpty _ toParse = do
	debugM ("Reading nothing from " ++ msg toParse ++ "...")
	[("", toParse)]
-- OpSpace
readAllMatches OpSpace _ "" = do
	debugM "Reading the end of text to parse as a word boundary..."
	[("", "")]
readAllMatches OpSpace previousCharIsAlphaNum toParse = do
	debugM $ "Attempting to read a space or word boundary from " ++ msg toParse ++ "..."
	let numberOfLeadingSpaces = Text.length $ Text.takeWhile isSpace toParse
	if numberOfLeadingSpaces > 0 then do
		debugM $ show numberOfLeadingSpaces ++ " space chars were parsed as an OpSpace"
		map (flip Text.splitAt toParse) [0..numberOfLeadingSpaces]
	else if previousCharIsAlphaNum /= isAlphaNum (Text.head toParse) then do
		let previousAlphanumDesc = (if previousCharIsAlphaNum then "an " else "a non") ++ "alphanumeric"
		debugM $ "A word boundary was matched for this OpSpace going from " ++ previousAlphanumDesc ++ " to '" ++ [Text.head toParse] ++ "'."
		[("", toParse)]
	else do
		debugM $ "No spaces were found and the previous char and the next, '" ++ [Text.head toParse] ++ "', were both " ++ (orEmpty (not previousCharIsAlphaNum) "non") ++ "alphanumeric."
		[]
-- OpAnd
readAllMatches (OpAnd subpatterns) previousCharIsAlphaNum toParse = do
	debugM $ "Attempting to read 'and' of " ++ (showWithAnd $ map show subpatterns) ++ " from " ++ msg toParse ++ "..."
	let readAllMatches' subpatterns' previousCharIsAlphaNum' charsReadSoFar =
		if null subpatterns'
			then [Text.splitAt charsReadSoFar toParse]
			else do
				let toParseRemaining = Text.drop charsReadSoFar toParse
				let matches = readAllMatches (head subpatterns') previousCharIsAlphaNum' toParseRemaining
				let readAllMatchesFrom (parsed, _) = readAllMatches' (tail subpatterns') (isAlphaNum $ Text.last parsed) (charsReadSoFar + Text.length parsed)
				concat $ map readAllMatchesFrom matches
	readAllMatches' subpatterns previousCharIsAlphaNum 0
-- OpLiteral
readAllMatches (OpLiteral literal) _ toParse = do
	debugM $ "Attempting to read " ++ msg literal ++ " from " ++ msg toParse ++ "..."
	if literal `Text.isPrefixOf` toParse
		then [(literal, Text.drop (Text.length literal) toParse)]
		else []
-- OpDelimiter
readAllMatches delimited@(OpDelimited delimiter delimitedGroup) previousCharIsAlphanum toParse = do
	debugM $ "Attempting to read " ++ msg delimiter ++ " delimited " ++ msgShow delimitedGroup ++ " from " ++ msg toParse ++ "..."
	let group1Matches = readAllMatches delimitedGroup previousCharIsAlphanum toParse
	let parseDelimiterAndMore = \toParse' -> do
		if (pack delimiter) `Text.isPrefixOf` toParse' then do
			let previousCharIsAlphaNum' = isAlphaNum $ last delimiter
			readAllMatches delimited previousCharIsAlphaNum' $ Text.drop (fromIntegral $ length delimiter) toParse'
		else
			[]
	concat $ map (\group1Match@(_, afterGroup1) -> group1Match:(parseDelimiterAndMore afterGroup1)) group1Matches

instance Show OpPattern where
	show OpEmpty = ""
	show OpSpace = " "
	show (OpAnd subpatterns) = foldl (++) "" $ map show subpatterns
	show (OpLiteral literal) = unpack literal
	show (OpDelimited delimiter subpattern) = "(" ++ show subpattern ++ "){" ++ wrap "\"" delimiter ++ "}"

instance Eq OpPattern where
	(==) OpEmpty OpEmpty = True
	(==) OpSpace OpSpace = True
	(==) (OpAnd ps1) (OpAnd ps2) = ps1 == ps2
	(==) (OpLiteral l1) (OpLiteral l2) = l1 == l2
	(==) (OpDelimited d1 p1) (OpDelimited d2 p2) = d1 == d2 && p1 == p2
	(==) _ _ = False
