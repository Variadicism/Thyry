module Beng.Parse.Patterns.And (
	parse
) where

import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (Populace2)

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Parsers ((@+>), (>:>), (>\>), Parser)
import Beng.Parse.Types.Patterns (Pattern)

-- exported

parse :: Populace2 Pattern -> Parser Match
parse subpatterns =
	show (length subpatterns) ++ " patterns" @+>
	parseAsP subpatterns.p1 >\> Match.And
	where
		parseAsP :: Populace Pattern -> Parser (Populace Match)
		parseAsP p = case P.uncons p of
			(next, []) -> Pattern.parse next >\> P.singleton
			(next, (nextHead:nextTail)) ->
				Pattern.parse next >:>
				parseAsP (P.Populace nextHead nextTail) >\>
				uncurry P.cons