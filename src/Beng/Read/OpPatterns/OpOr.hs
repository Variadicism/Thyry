module Beng.Read.OpPatterns.OpOr (
	readAllMatches
) where

import Utils.Lists (showWithOr)
import Utils.Messaging (debugM, msg)
import Utils.Readers (MultiReader)

import {-# SOURCE #-} qualified Beng.Read.OpPatterns as OpPattern
import Beng.Types.OpPatterns (OpPattern)

import Data.Text.Lazy (Text)

readAllMatches :: [OpPattern] -> Bool -> MultiReader Text
readAllMatches subpatterns wordPrecedes = \toParse -> do
	debugM $ "Attempting to read " ++ (showWithOr $ map show subpatterns) ++ " from " ++ msg toParse ++ "..."
	case subpatterns of
		[] -> [("", toParse)]
		_ -> concat $ map (\subpattern -> OpPattern.readAllMatches subpattern wordPrecedes toParse) subpatterns