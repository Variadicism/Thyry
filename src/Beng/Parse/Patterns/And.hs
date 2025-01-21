module Beng.Parse.Patterns.And (
	parse,
	compareFrom
) where

import Utils.Populace.Populace2 (Populace2, dualton)
import qualified Utils.Populace.Populace2 as P2

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>:>), (>\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (comparator)
import qualified Beng.Parse.Parsers.PatternComparator as PC
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Patterns (Pattern)

-- exported

parse :: Populace2 Pattern -> Code.Parser Match
parse subpatterns =
	show (length subpatterns) ++ " patterns" @+>
	parseAsP subpatterns >\> Match.And
	where
		parseAsP :: Populace2 Pattern -> Code.Parser (Populace2 Match)
		parseAsP p = case p.tailTail of
			[] ->
				Pattern.parse p.head >:>
				Pattern.parse p.next >\>
				uncurry dualton
			tailTailHead:tailTailTail ->  -- This naming scheme is quickly getting ridiculous. :P
				Pattern.parse p.head >:>
				parseAsP (P2.Populace2 p.next tailTailHead tailTailTail) >\>
				uncurry P2.cons

compareFrom :: Populace2 Pattern -> PatternComparator.Parser
compareFrom subpatterns =
	show (length subpatterns) ++ " pattern comparator" @> \state ->
		state{ PC.rest = state.rest{ PC.sub = subpatterns.l ++ tail state.rest.sub }} >>> comparator