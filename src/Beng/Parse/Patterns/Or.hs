module Beng.Parse.Patterns.Or (
	parse
) where

import Utils.Lists (removeAt)
import qualified Utils.Maps.Ordered as OMap
import Utils.Populace.Populace2 (Populace2)
import qualified Utils.Populace.Populace2 as P2

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers.Code (Parser, (@+>), (>\>), parseAny)
import Beng.Types.Parse.Patterns (Pattern)

import qualified Data.Map.Ordered as OMap

-- exported

parse :: Populace2 Pattern -> Parser Match
parse subpatterns = show (length subpatterns) ++ " possible patterns" @+>
	(parseAny $ P2.toP1 $ P2.mapIndexed parserForSubpattern subpatterns)
	where
		parserForSubpattern :: Int -> Pattern -> Parser Match
		parserForSubpattern matchIndex pattern =
			Pattern.parse pattern >\> \match -> do
				let missedSubpatterns = removeAt matchIndex subpatterns.l
				let misses = OMap.values $
					OMap.filter (\k _ -> k `OMap.notMember` Match.getArgs match) $
					OMap.concat $ map Pattern.getArgs missedSubpatterns
				Match.Or { match, matchIndex, misses }