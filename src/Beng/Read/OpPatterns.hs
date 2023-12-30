module Beng.Read.OpPatterns (
	readAllMatches
) where

import Utils.Lists
import Utils.Messaging
import Utils.Tuples (mapFst2)

import Beng.Types.OpPatterns (OpPattern(..))

import Data.Char (isAlphaNum, isSpace)
import Data.Text.Lazy (Text, pack)
import qualified Data.Text.Lazy as Text (concat, drop, head, isPrefixOf, last, length, splitAt, takeWhile)

-- Theory note: no OpPatterns can contain OpArgs; OpArgs can never be in any kind of "optional" group and will be included in `argsAndSuffixes` rather than `OpAnd`s.
-- In the future, the Maybe will become a list so that all possible matches can be given and the tuple at the end will include capturing group data (Map String String).
readAllMatches ::
	OpPattern ->  -- ^ The OpPattern to attempt to parse from the beginning of some text
	Bool ->       -- ^ The previous character exists (i.e., not the beginning of a code stream) and is an alphanumeric character
	Text ->       -- ^ The text to attempt to parse the given OpPattern
	[(Text, Text)]    -- ^ For each possible way for the given OpPattern to match the start of the given Text, (the text matched to the given OpPattern, the text remaining after parsing)
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
	let spaceParses = do
		let subjectVerb =
			if numberOfLeadingSpaces == 1
				then "1 space char was"
				else show numberOfLeadingSpaces ++ " space chars were"
		debugM $ subjectVerb ++ " parsed as an OpSpace."
		map (flip Text.splitAt toParse) [1..numberOfLeadingSpaces]

	let hasBoundary = previousCharIsAlphaNum /= isAlphaNum (Text.head toParse)
	let wordBoundaryExistence = if hasBoundary then "A" else "No"
	let previousAlphanumDesc = (if previousCharIsAlphaNum then "an " else "a non") ++ "alphanumeric"
	debugM $ wordBoundaryExistence ++ " word boundary was matched for this OpSpace going from " ++ previousAlphanumDesc ++ " to '" ++ [Text.head toParse] ++ "'."

	listIf [(hasBoundary, ("", toParse))] ++ spaceParses
-- OpOr
readAllMatches (OpOr subpatterns) previousCharIsAlphaNum toParse = do
	debugM $ "Attempting to read " ++ (showWithOr $ map show subpatterns) ++ " from " ++ msg toParse ++ "..."
	case subpatterns of
		[] -> [("", toParse)]
		_ -> concat $ map (\subpattern -> readAllMatches subpattern previousCharIsAlphaNum toParse) subpatterns
-- OpAnd
readAllMatches (OpAnd subpatterns) previousCharIsAlphaNum toParse = do
	debugM $ "Attempting to read " ++ (showWithAnd $ map show subpatterns) ++ " from " ++ msg toParse ++ "..."
	let readAllMatches' subpatterns' previousCharIsAlphaNum' charsReadSoFar =
		case subpatterns' of
			[] -> [Text.splitAt charsReadSoFar toParse]
			(nextSubpattern:remainingSubpatterns) -> do
				let toParseRemaining = Text.drop charsReadSoFar toParse
				let matches = readAllMatches nextSubpattern previousCharIsAlphaNum' toParseRemaining
				let readAllMatchesFrom (parsed, _) = readAllMatches' remainingSubpatterns (isAlphaNum $ Text.last parsed) (charsReadSoFar + Text.length parsed)
				concat $ map readAllMatchesFrom matches
	readAllMatches' subpatterns previousCharIsAlphaNum 0
-- OpLiteral
readAllMatches (OpLiteral literal) _ toParse = do
	debugM $ "Attempting to read " ++ msg literal ++ " from " ++ msg toParse ++ "..."
	if literal `Text.isPrefixOf` toParse
		then [(literal, Text.drop (Text.length literal) toParse)]
		else []
-- OpDelimited
readAllMatches delimited@(OpDelimited delimiter delimitedGroup) previousCharIsAlphanum toParse = do
	debugM $ "Attempting to read " ++ msg delimiter ++ " delimited " ++ msgShow delimitedGroup ++ " from " ++ msg toParse ++ "..."
	let group1Matches = readAllMatches delimitedGroup previousCharIsAlphanum toParse
	let parseDelimiterAndMore = \toParse' -> do
		if (pack delimiter) `Text.isPrefixOf` toParse' then do
			let previousCharIsAlphaNum' = isAlphaNum $ last delimiter
			readAllMatches delimited previousCharIsAlphaNum' $ Text.drop (fromIntegral $ length delimiter) toParse'
		else
			[]
	let parseDelimitedGroups = \group1Match@(group1MatchText, afterGroup1) -> do
		let afterGroup1DelimitedParses = parseDelimiterAndMore afterGroup1
		let addGroup1AndDelimiter = \t -> Text.concat [group1MatchText, pack delimiter, t]
		let groupNMatches = map (mapFst2 addGroup1AndDelimiter) afterGroup1DelimitedParses
		group1Match:groupNMatches
	concat $ map parseDelimitedGroups group1Matches
