module Beng.Read.OpPatterns.OpEmpty (
	readAllMatches
) where

import Utils.Messaging (debugM, msg)
import Utils.Readers (MultiReader)

import Data.Text.Lazy (Text)

readAllMatches :: MultiReader Text
readAllMatches toParse = do
	debugM ("Reading nothing from " ++ msg toParse ++ "...")
	[("", toParse)]