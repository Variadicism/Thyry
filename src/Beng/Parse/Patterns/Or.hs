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
import {-# SOURCE #-} Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>:>), (>\>), parseAny)
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (internallySatisfies)
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import qualified Beng.Types.Parse.Patterns as TypePattern
import Beng.Types.Parse.Patterns (
	Comparison(..),
	ComparatorState(..),
	Mismatch(..),
	Or(..),
	Pattern,
	SomePattern(..))

import qualified Data.Map.Ordered as OrderedMap
import Data.List (intercalate)
import qualified Data.Set as Set

parseOr :: Or -> Code.Parser Match.Or
parseOr (Or subpatterns) = show (length subpatterns) ++ " possible patterns" @+>
	parseAny (P2.toP1 $ P2.mapIndexed (parserForSubpattern subpatterns) subpatterns)

parserForSubpattern :: P2.Populace2 SomePattern -> Int -> SomePattern -> Code.Parser Match.Or
parserForSubpattern subpatterns matchIndex pattern =
	Pattern.parse pattern >\> \match -> do
		let missedSubpatterns = removeAt matchIndex subpatterns.l
		let misses = OMap.values $
			OrderedMap.filter (\k _ -> k `OrderedMap.notMember` Match.getArgs match) $
			OMap.concat $ map Pattern.getArgs missedSubpatterns
		Match.Or { match, matchIndex, misses }

compareAsCandidateOr :: Or -> PatternComparator.Parser
compareAsCandidateOr self@(Or subpatterns) = show (length subpatterns) ++ " possible pattern comparator" @> \state ->
	case state.rest.requirement of
		[] -> Error $ LeftoverCandidate $ P.singleton $ SomePattern self
		nextRequirement:_ -> do
			sequence $ P2.map ((state, nextRequirement) `internallySatisfies`) subpatterns
			PatternComparator.accept [nextRequirement] state

compareAsRequirementOr :: Or -> PatternComparator.Parser
compareAsRequirementOr (Or subpatterns) =
	show (length subpatterns) ++ " possible requirement comparator" @> \state ->
	case state.rest.candidate of
		nextCandidate:_ -> case Pattern.asPattern nextCandidate :: Maybe Or of
			Just Or{} -> dispatchCurrentCandidate nextCandidate state
			Nothing -> branchOptions state
		[] -> branchOptions state
	where
		dispatchCurrentCandidate (SomePattern pattern) state =
			state >>> TypePattern.compareAsCandidate pattern >:> PatternComparator.comparator >\> const ()

		branchOptions state = do
			case state.rest.requirement of
				_:requirementLeft -> do
					let parserFor i option =
							"possible requirement pattern " ++
								show (i + 1) ++ "/" ++ show (length subpatterns) ++
								" " ++ show option @> \state' ->
									PatternComparator.swapRequirement (option:requirementLeft) state' >>> PatternComparator.comparator
					state >>> parseAny (P2.toP1 $ P2.mapIndexed parserFor subpatterns)
				[] -> case state.rest.candidate of
					nextCandidate:candidateLeft -> Error $ LeftoverCandidate $ P.Populace nextCandidate candidateLeft
					[] -> PatternComparator.acceptRest state

instance Eq Or where
	Or a == Or b = a == b

instance Show Or where
	show (Or subpatterns) = "(" ++ intercalate "|" (map show subpatterns.l) ++ ")"

instance Messagable Or where
	msg (Or subpatterns) = "(" ++ intercalate "|" (map msg subpatterns.l) ++ ")"

instance Pattern Match.Or Or where
	parse = parseOr
	compareAsCandidate = compareAsCandidateOr
	compareAsRequirement = compareAsRequirementOr
	getSubpatterns (Or subpatterns) = subpatterns.p1
	mustHavePrefix (Or subpatterns) = all Pattern.mustHavePrefix subpatterns.l
	mustHaveSuffix (Or subpatterns) = all Pattern.mustHaveSuffix subpatterns.l
	canHavePrefix (Or subpatterns) = any Pattern.canHavePrefix subpatterns.l
	canHaveSuffix (Or subpatterns) = any Pattern.canHaveSuffix subpatterns.l
	canMatchEmpty (Or subpatterns) = any Pattern.canMatchEmpty subpatterns.l
	startingSpaceStates (Or subpatterns) =
		foldl Set.union mempty $ map Pattern.startingSpaceStates subpatterns.l
	isOptional (Or subpatterns) = any Pattern.isOptional subpatterns.l
	getArgsUsing getArgs (Or subpatterns) = OMap.map fst $ Pattern.getOrArgsUsing getArgs subpatterns

parse :: Or -> Code.Parser Match.Or
parse = parseOr
