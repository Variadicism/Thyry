module Beng.Read.OpPatterns.OpLiteral (
	readAllMatches
) where

import Utils.Messaging (debugM, msg)
import Utils.Readers (MultiReader)

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

readAllMatches :: Text -> MultiReader Text
readAllMatches literal = \toParse -> do
	debugM $ "Attempting to read " ++ msg literal ++ " from " ++ msg toParse ++ "..."
	if literal `Text.isPrefixOf` toParse
		then [(literal, Text.drop (Text.length literal) toParse)]
		else []