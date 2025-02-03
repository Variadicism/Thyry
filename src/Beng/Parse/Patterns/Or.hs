module Beng.Parse.Patterns.Or (
	parse,
	compareFrom
) where

import Utils.Fallible
import Utils.Lists (removeAt)
import qualified Utils.Maps.Ordered as OMap
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (Populace2)
import qualified Utils.Populace.Populace2 as P2

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>\>), parseAny)
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (internallySatisfies)
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import qualified Beng.Parse.Parsers.PatternComparator as PC
import Beng.Types.Parse.Patterns (Mismatch(..), Pattern(Or))

import qualified Data.Map.Ordered as OMap

-- exported

parse :: Populace2 Pattern -> Code.Parser Match
parse subpatterns = show (length subpatterns) ++ " possible patterns" @+>
	(parseAny $ P2.toP1 $ P2.mapIndexed parserForSubpattern subpatterns)
	where
		parserForSubpattern :: Int -> Pattern -> Code.Parser Match
		parserForSubpattern matchIndex pattern =
			Pattern.parse pattern >\> \match -> do
				let missedSubpatterns = removeAt matchIndex subpatterns.l
				let misses = OMap.values $
					OMap.filter (\k _ -> k `OMap.notMember` Match.getArgs match) $
					OMap.concat $ map Pattern.getArgs missedSubpatterns
				Match.Or { match, matchIndex, misses }

compareFrom :: Populace2 Pattern -> PatternComparator.Parser
compareFrom subpatterns = show (length subpatterns) ++ " possible pattern comparator" @> \state ->
	case state.rest.super of
		[] -> Error $ LeftoverSub $ P.singleton $ Or subpatterns
		nextSuper:_ -> do
			sequence $ P2.map ((state, nextSuper) `internallySatisfies`) subpatterns
			PC.accept [nextSuper] state