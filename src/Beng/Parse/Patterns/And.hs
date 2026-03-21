module Beng.Parse.Patterns.And (
	parse
) where

import Utils.Lists (takeUntilIncl)
import qualified Utils.Maps.Ordered as OMap
import Utils.Messaging (Messagable(..), msg)
import Utils.Populace.Populace2 (dualton)
import qualified Utils.Populace.Populace2 as P2

import qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>:>), (>\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (comparator)
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Patterns (And(..), Comparison(..), ComparatorState(..), Space(..), asPattern)

parseAnd :: And -> Code.Parser Match
parseAnd (And subpatterns) =
	show (length subpatterns) ++ " patterns" @+>
	parseAsP subpatterns >\> Match.And
	where
		parseAsP p = case p.tailTail of
			[] ->
				Pattern.parse p.head >:>
				Pattern.parse p.next >\>
				uncurry dualton
			tailTailHead:tailTailTail ->
				Pattern.parse p.head >:>
				parseAsP (P2.Populace2 p.next tailTailHead tailTailTail) >\>
				uncurry P2.cons

compareFromAnd :: And -> PatternComparator.Parser
compareFromAnd (And subpatterns) =
	show (length subpatterns) ++ " pattern comparator" @> \state ->
		state{ rest = state.rest{ sub = subpatterns.l ++ tail state.rest.sub }} >>> comparator

instance Messagable And where
	msg = show

instance TPattern.Pattern And where
	parse = parseAnd
	compareFrom = compareFromAnd
	showPatternWith useMsg (And subpatterns) =
		concatMap (\p -> if useMsg then msg p else show p) subpatterns.l
	getSubpatterns (And subpatterns) = subpatterns.p1
	mustHavePrefix (And subpatterns) =
		any Pattern.mustHavePrefix $ takeUntilIncl Pattern.hasArgs subpatterns.l
	mustHaveSuffix (And subpatterns) =
		any Pattern.mustHaveSuffix $ takeUntilIncl Pattern.hasArgs $ reverse subpatterns.l
	canHavePrefix (And subpatterns) =
		any Pattern.canHavePrefix $ takeUntilIncl Pattern.hasArgs subpatterns.l
	canHaveSuffix (And subpatterns) =
		any Pattern.canHaveSuffix $ takeUntilIncl Pattern.hasArgs $ reverse subpatterns.l
	isOptional (And subpatterns) =
		let notSpace pattern = case asPattern pattern :: Maybe Space of
			Just _ -> False
			Nothing -> True
		in all Pattern.isOptional $ filter notSpace subpatterns.l
	getArgsUsing getArgs (And subpatterns) = OMap.concat $ map getArgs subpatterns.l

parse :: And -> Code.Parser Match
parse = parseAnd
