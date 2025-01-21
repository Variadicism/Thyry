module Beng.Parse.Patterns.Delimited (
	parse,
	compareFrom
) where

import qualified Utils.Maps.Ordered as OMap
import Utils.Populace (Populace(..))

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Parse.Parsers ((>:>), (>\>), (@+>))
import qualified Beng.Parse.Parsers.Code as Code
import qualified Beng.Parse.Parsers.PatternComparator as PC
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Patterns (Pattern)

-- exported

parse :: Pattern -> Pattern -> Code.Parser Match
parse delimiter delimitend = show delimitend ++ " by " ++ show delimiter @+>
	Pattern.parse delimitend >:>
	(Code.parseAll (Pattern.parse delimiter >:> Pattern.parse delimitend) >\> \case
		[] -> Match.DelimitedTailMissing $ OMap.values $
			Pattern.getArgs $ Pattern.Delimited delimiter delimitend
		firstMatch:matchTail -> Match.DelimitedTailMatch $ Populace firstMatch matchTail) >\>
	uncurry Match.Delimited

compareFrom :: Pattern -> Pattern -> PatternComparator.Parser
compareFrom delimiter delimitend = show delimitend ++ " by " ++ show delimiter ++ " comparator" @+>
		PatternComparator.compareFrom delimitend >:>
		(PC.parseAll $ PC.compareFrom delimiter >:> PC.compareFrom delimitend >\> const ()) >\>
		const ()