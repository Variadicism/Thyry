module Beng.Parse.Patterns.Or (
	parse
) where

import Utils.Lists (removeAt)

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Types.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers (Parser, (@+>), (>\>), parseAny)
import Beng.Parse.Types.Patterns (Pattern)

import qualified Data.Map.Ordered as OMap

-- exported

parse :: [Pattern] -> Parser Match
parse subpatterns = show (length subpatterns) ++ " possible patterns" @+>
	(parseAny $ map (uncurry parserForSubpattern) $ zip [0..] subpatterns)
	where
		parserForSubpattern :: Int -> Pattern -> Parser Match
		parserForSubpattern matchIndex pattern =
			Pattern.parse pattern >\> \match -> do
				let matchedArgNames = map fst $ OMap.assocs $ Match.getArgs match
				let misses =
					-- Filter because the same argument can appear in multiple options.
					filter (`notElem` matchedArgNames) $
						map fst $ concatMap (OMap.assocs . Pattern.getArgs) $ removeAt matchIndex subpatterns
				Match.Or { match, matchIndex, misses }