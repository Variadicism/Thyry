module Beng.Parse.Patterns.And (
	parse
) where

import Utils.Fallible
import Utils.Lists (takeUntilIncl)
import qualified Utils.Maps.Ordered as OMap
import Utils.Messaging (Messagable(..), msg)
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (dualton)
import qualified Utils.Populace.Populace2 as P2

import qualified Beng.Parse.Patterns as Pattern
import {-# SOURCE #-} Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Matches (SomeMatch)
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>:>), (>\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (acceptRest, comparator)
import Beng.Types.Parse.Parsers.PatternComparator (
	Comparator,
	Comparison(..),
	ComparatorState(..))
import Beng.Types.Parse.Patterns (
	And(..),
	Mismatch(..),
	Pattern(..),
	SomePattern(..))

import Data.Set (Set)
import qualified Data.Set as Set

parseAnd :: And -> Code.Parser Match.And
parseAnd (And subpatterns) =
	show (length subpatterns) ++ " patterns" @+>
	parseAsP subpatterns >\> Match.And

parseAsP :: P2.Populace2 SomePattern -> Code.Parser (P2.Populace2 SomeMatch)
parseAsP p = case p.tailTail of
	[] ->
		Pattern.parse p.head >:>
		Pattern.parse p.next >\>
		uncurry dualton
	tailTailHead:tailTailTail ->
		Pattern.parse p.head >:>
		parseAsP (P2.Populace2 p.next tailTailHead tailTailTail) >\>
		uncurry P2.cons

compareAsCandidateAnd :: And -> Comparator
compareAsCandidateAnd self@(And subpatterns) =
	show (length subpatterns) ++ " pattern comparator" @> \state ->
		case state.rest.candidate of
			_:candidateLeft ->
				state{ rest = state.rest{ candidate = subpatterns.l ++ candidateLeft }} >>> comparator
			[] -> case state.rest.requirement of
				next:requirementLeft -> Error $ Mismatch (SomePattern self) $ P.Populace next requirementLeft
				[] -> acceptRest state

compareAsRequirementAnd :: And -> Comparator
compareAsRequirementAnd (And subpatterns) =
	show (length subpatterns) ++ " requirement comparator" @> \state ->
		case state.rest.requirement of
			_:requirementLeft ->
				state{ rest = state.rest{ requirement = subpatterns.l ++ requirementLeft }} >>> comparator
			[] -> case state.rest.candidate of
				nextCandidate:candidateLeft -> Error $ LeftoverCandidate $ P.Populace nextCandidate candidateLeft
				[] -> acceptRest state

instance Eq And where
	And a == And b = a == b

instance Show And where
	show (And subpatterns) = concatMap show subpatterns.l

instance Messagable And where
	msg (And subpatterns) = concatMap msg subpatterns.l

instance Pattern Match.And And where
	parse = parseAnd
	compareAsCandidate = compareAsCandidateAnd
	compareAsRequirement = compareAsRequirementAnd
	getSubpatterns (And subpatterns) = subpatterns.p1
	mustHavePrefix (And subpatterns) =
		any Pattern.mustHavePrefix $ takeUntilIncl Pattern.hasArgs subpatterns.l
	mustHaveSuffix (And subpatterns) =
		any Pattern.mustHaveSuffix $ takeUntilIncl Pattern.hasArgs $ reverse subpatterns.l
	canHavePrefix (And subpatterns) =
		any Pattern.canHavePrefix $ takeUntilIncl Pattern.hasArgs subpatterns.l
	canHaveSuffix (And subpatterns) =
		any Pattern.canHaveSuffix $ takeUntilIncl Pattern.hasArgs $ reverse subpatterns.l
	canMatchEmpty (And subpatterns) = all Pattern.canMatchEmpty subpatterns.l
	startingSpaceStates (And subpatterns) = firstStates subpatterns.l
	isOptional (And subpatterns) = all Pattern.isOptional subpatterns.l
	getArgsUsing getArgs (And subpatterns) = OMap.concat $ map getArgs subpatterns.l

firstStates :: [SomePattern] -> Set Code.SpaceState
firstStates patterns = case patterns of
	[] -> mempty
	pattern:rest -> if Pattern.canMatchEmpty pattern then
		Pattern.startingSpaceStates pattern `Set.union` firstStates rest
	else
		Pattern.startingSpaceStates pattern
