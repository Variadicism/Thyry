{-# LANGUAGE InstanceSigs, OverloadedStrings #-}

module OpPatterns (
	OpPattern(..),
	readAllMatches
) where

import Utils.Errors
import Utils.Messaging (msg)

import Data.Text.Lazy (Text, pack, unpack)
import qualified Data.Text.Lazy as Text (drop, isPrefixOf, length, splitAt)

data OpPattern = OpEmpty | OpLiteral Text | OpAnd [OpPattern]

-- In the future, the Maybe will become a list so that all possible matches can be given and the tuple at the end will include capturing group data (Map String String).
readAllMatches ::
	OpPattern ->  -- ^ The OpPattern to attempt to parse from the beginning of some text
	Text ->       -- ^ The text to attempt to parse the given OpPattern
	Fallible (Text, Text)    -- ^ (The text matched to the given OpPattern, the text remaining after parsing) or an error if the given OpPattern was not matched at the beginning of the given Text
-- OpEmpty
readAllMatches OpEmpty toParse = fallible ("", toParse)
-- OpAnd
readAllMatches (OpAnd subpatterns) toParse =
	let readAllMatches' = \subpatterns' charsReadSoFar ->
		if null subpatterns'
			then return $ Text.splitAt charsReadSoFar toParse
			else do
				let toParseRemaining = Text.drop charsReadSoFar toParse
				(parsed, _) <- readAllMatches (head subpatterns') toParseRemaining
				readAllMatches' (tail subpatterns') (charsReadSoFar + Text.length parsed)
	in readAllMatches' subpatterns 0
-- OpLiteral
readAllMatches (OpLiteral literal) toParse =
	if literal `Text.isPrefixOf` toParse
		then fallible $ (literal, Text.drop (Text.length literal) toParse)
		else toError $ msg toParse ++ " does not begin with \"" ++ msg literal ++ "\"!"

instance Show OpPattern where
	show OpEmpty = ""
	show (OpAnd subpatterns) = if null subpatterns then "()" else foldl1 (++) $ map show subpatterns
	show (OpLiteral literal) = unpack literal

instance Eq OpPattern where
	-- OpEmpty
	(==) OpEmpty OpEmpty = True
	-- OpAnd
	(==) (OpAnd ps1) (OpAnd ps2) = ps1 == ps2
	-- OpLiteral
	(==) (OpLiteral l1) (OpLiteral l2) = l1 == l2
	-- ALL ELSE
	(==) _ _ = False
