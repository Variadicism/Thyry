module Beng.Parse.Patterns.Or (
	parse
) where

import Utils.Fallible
import Utils.Lists (removeAt)
import qualified Utils.Maps.Ordered as OMap
import Utils.Messaging (Messagable(..), msg)
import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2

import qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Matches (Match)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>\>), parseAny)
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (internallySatisfies)
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import qualified Beng.Parse.Parsers.PatternComparator as PC
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Patterns (Comparison(..), ComparatorState(..), Mismatch(..), Or(..), SomePattern(..))

import qualified Data.Map.Ordered as OrderedMap
import Data.List (intercalate)

parseOr :: Or -> Code.Parser Match
parseOr (Or subpatterns) = show (length subpatterns) ++ " possible patterns" @+>
	(parseAny $ P2.toP1 $ P2.mapIndexed parserForSubpattern subpatterns)
	where
		parserForSubpattern matchIndex pattern =
			Pattern.parse pattern >\> \match -> do
				let missedSubpatterns = removeAt matchIndex subpatterns.l
				let misses = OMap.values $
					OrderedMap.filter (\k _ -> k `OrderedMap.notMember` Match.getArgs match) $
					OMap.concat $ map Pattern.getArgs missedSubpatterns
				Match.Or { match, matchIndex, misses }

compareFromOr :: Or -> PatternComparator.Parser
compareFromOr self@(Or subpatterns) = show (length subpatterns) ++ " possible pattern comparator" @> \state ->
	case state.rest.super of
		[] -> Error $ LeftoverSub $ P.singleton $ SomePattern self
		nextSuper:_ -> do
			sequence $ P2.map ((state, nextSuper) `internallySatisfies`) subpatterns
			PC.accept [nextSuper] state

instance Eq Or where
	Or a == Or b = a == b

instance Show Or where
	show = TPattern.showPatternWith False

instance Messagable Or where
	msg = show

instance TPattern.Pattern Or where
	parse = parseOr
	compareFrom = compareFromOr
	showPatternWith useMsg (Or subpatterns) =
		"(" ++ intercalate "|" (map (\p -> if useMsg then msg p else show p) subpatterns.l) ++ ")"
	getSubpatterns (Or subpatterns) = subpatterns.p1
	mustHavePrefix (Or subpatterns) = all Pattern.mustHavePrefix subpatterns.l
	mustHaveSuffix (Or subpatterns) = all Pattern.mustHaveSuffix subpatterns.l
	canHavePrefix (Or subpatterns) = any Pattern.canHavePrefix subpatterns.l
	canHaveSuffix (Or subpatterns) = any Pattern.canHaveSuffix subpatterns.l
	isOptional (Or subpatterns) = any Pattern.isOptional subpatterns.l
	getArgsUsing getArgs (Or subpatterns) = OMap.map fst $ Pattern.getOrArgsUsing getArgs subpatterns

parse :: Or -> Code.Parser Match
parse = parseOr
