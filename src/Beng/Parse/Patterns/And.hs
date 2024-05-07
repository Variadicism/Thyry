module Beng.Parse.Patterns.And (
	parse
) where

import Utils.Populace.Populace2 (Populace2, dualton)
import qualified Utils.Populace.Populace2 as P2

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@+>), (>:>), (>\>), Parser)
import Beng.Types.Parse.Patterns (Pattern)

-- exported

parse :: Populace2 Pattern -> Parser Match
parse subpatterns =
	show (length subpatterns) ++ " patterns" @+>
	parseAsP subpatterns >\> Match.And
	where
		parseAsP :: Populace2 Pattern -> Parser (Populace2 Match)
		parseAsP p = case p.tailTail of
			[] ->
				Pattern.parse p.head >:>
				Pattern.parse p.next >\>
				uncurry dualton
			tailTailHead:tailTailTail ->  -- This naming scheme is quickly getting ridiculous. :P
				Pattern.parse p.head >:>
				parseAsP (P2.Populace2 p.next tailTailHead tailTailTail) >\>
				uncurry P2.cons