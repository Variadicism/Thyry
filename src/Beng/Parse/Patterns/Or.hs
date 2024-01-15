module Beng.Parse.Patterns.Or (
	parse
) where

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Types.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Parsers (Parser, (@+>), (>\>), parseAny)
import Beng.Parse.Types.Patterns (Pattern)

-- exported

parse :: [Pattern] -> Parser Match
parse subpatterns = show (length subpatterns) ++ " possible patterns" @+>
	(parseAny $ map (uncurry parserForSubpattern) $ zip [0..] subpatterns)
	where
		parserForSubpattern :: Int -> Pattern -> Parser Match
		parserForSubpattern matchIndex pattern =
			Pattern.parse pattern >\>
			\match -> Match.Or { match, matchIndex }