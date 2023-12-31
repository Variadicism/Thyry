module Beng.Read.OpPatterns.OpSpace (
	readAllMatches
) where

import Utils.Lists (listIf)
import Utils.Messaging (debugM, msg)
import Utils.Readers (MultiReader)

import Data.Char (isAlphaNum, isSpace)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

readAllMatches :: Bool -> MultiReader Text
readAllMatches _ "" = do
	debugM "Reading the end of text to parse as a word boundary..."
	[("", "")]
readAllMatches wordPrecedes toParse = do
	debugM $ "Attempting to read a space or word boundary from " ++ msg toParse ++ "..."
	let numberOfLeadingSpaces = Text.length $ Text.takeWhile isSpace toParse
	let spaceParses = do
		let subjectVerb =
			if numberOfLeadingSpaces == 1
				then "1 space char was"
				else show numberOfLeadingSpaces ++ " space chars were"
		debugM $ subjectVerb ++ " parsed as an OpSpace."
		map (flip Text.splitAt toParse) [1..numberOfLeadingSpaces]

	let hasBoundary = wordPrecedes /= isAlphaNum (Text.head toParse)
	let wordBoundaryExistence = if hasBoundary then "A" else "No"
	let wordPrecedesDesc = (if wordPrecedes then "an " else "a non") ++ "alphanumeric"
	debugM $ wordBoundaryExistence ++ " word boundary was matched for this OpSpace going from " ++
		wordPrecedesDesc ++ " to '" ++ [Text.head toParse] ++ "'."

	listIf [(hasBoundary, ("", toParse))] ++ spaceParses