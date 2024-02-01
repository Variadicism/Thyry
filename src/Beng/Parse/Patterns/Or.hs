module Beng.Parse.Patterns.Or (
	parse
) where

import Utils.Lists (removeAt)
import qualified Utils.Maps.Ordered as OMap
import Utils.Populace.Populace2 (Populace2)
import qualified Utils.Populace.Populace2 as P2

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Types.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers (Parser, (@+>), (>\>), parseAny)
import Beng.Parse.Types.Patterns (Pattern)

import qualified Data.Map.Ordered as OMap

-- exported

parse :: Populace2 Pattern -> Parser Match
parse subpatterns = show (length subpatterns) ++ " possible patterns" @+>
	(parseAny $ P2.toP1 $ P2.mapIndexed parserForSubpattern subpatterns)
	where
		parserForSubpattern :: Int -> Pattern -> Parser Match
		parserForSubpattern matchIndex pattern =
			Pattern.parse pattern >\> \match -> do
				let matchedArgNames = map fst $ OMap.assocs $ Match.getArgs match
				let misses =
					-- Filter because the same argument can appear in multiple options.
					filter (`notElem` matchedArgNames) $
						concatMap (OMap.keys . Pattern.getArgs) $
						removeAt matchIndex subpatterns.l
				Match.Or { match, matchIndex, misses }