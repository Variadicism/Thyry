module Beng.Parse.Parsers.PatternComparator (
	startState,
	swapCandidate,
	swapRequirement,
	acceptRest,
	acceptRequirementOnly,
	acceptUsing,
	accept,
	parseAll,
	parseWhile,
	internallySatisfies,
	compareAsRequirementDefault,
	comparator,
	module Beng.Types.Parse.Parsers.PatternComparator
) where

import Utils.Fallible
import Utils.Messaging (Messagable, msg, msgList)
import qualified Utils.Populace as P

import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>:>), (>|>))
import {-# SOURCE #-} qualified Beng.Parse.Parsers as Parser
import Beng.Build.TypeTest (TypeTest)
import {-# SOURCE #-} Beng.Parse.Patterns (isOptional)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Parsers.PatternComparator (
	Comparison(..),
	Comparator,
	ComparatorState(..),
	Parse,
	ParseRunner,
	Parses)
import Beng.Types.Parse.Patterns (And(..), Literal(..), Mismatch(..), SomePattern(..))
import qualified Beng.Types.Parse.Patterns as Pattern

import Control.Applicative ((<|>))
import Data.List (isPrefixOf)
import qualified Data.Text.Lazy as Text
import Data.Typeable (cast)

deriving instance Eq Comparison
deriving instance Eq ComparatorState

instance Parser.State Comparison ComparatorState where
	rest = rest
	indentation = indentation
	indent s = s{ indentation = s.indentation + 1 }
	outdent s = s{ indentation = s.indentation - 1 }

instance Messagable Comparison where
	msg Comparison{..} = msgList candidate ++ " in? " ++ msgList requirement

instance Show Comparison where
	show Comparison{..} = show candidate ++ " in? " ++ show requirement

instance Ord Comparison where
	compare c1 c2 =
		compare (length c1.candidate) (length c2.candidate) <>
			compare (length c1.requirement) (length c2.requirement)

instance Semigroup Comparison where
	a <> b = Comparison {
		candidate = a.candidate ++ b.candidate,
		requirement = a.requirement ++ b.requirement }

instance Messagable ComparatorState where
	msg ComparatorState{..} = msg rest

instance Show ComparatorState where
	show ComparatorState{..} = show rest ++ " at depth " ++ show indentation

spaceStateOfLiteral :: SomePattern -> Maybe Code.SpaceState
spaceStateOfLiteral pattern = do
	SomePattern somePattern <- return pattern
	Literal literal <- cast somePattern
	if Text.null literal
		then Nothing
		else Just $ Code.spaceStateOfChar $ Text.last literal

comparisonSpaceState :: Comparison -> Maybe Code.SpaceState
comparisonSpaceState Comparison{..} = do
	let ofPatterns patterns = foldl (\acc pattern -> acc <|> spaceStateOfLiteral pattern) Nothing $ reverse patterns
	ofPatterns candidate <|> ofPatterns requirement

flat :: SomePattern -> [SomePattern]
flat pattern@(SomePattern somePattern) = case cast somePattern of
	Just (And subpatterns) -> subpatterns.l
	Nothing -> [pattern]

takeAs1 :: Comparison -> t -> ComparatorState -> Parser.Parse Comparison ComparatorState t
takeAs1 parsed target state =
	if not $
		parsed.candidate `isPrefixOf` state.rest.candidate &&
			parsed.requirement `isPrefixOf` state.rest.requirement
	then
		error $ "A pattern comparator illegally requested that " ++ show parsed.candidate ++
			" should be accepted from " ++ show state.rest.candidate ++ " (candidate) and " ++
				show parsed.requirement ++ " from " ++ show state.rest.requirement ++ " (requirement)!"
	else do
		let requirement = case drop (length parsed.requirement) state.rest.requirement of
			nextRequirement:requirementLeft -> flat nextRequirement ++ requirementLeft
			newRequirement -> newRequirement
		Parser.Parse {
			parsed,
			target,
			state = state{
				atStart = False,
				spaceState = maybe state.spaceState id $ comparisonSpaceState parsed,
				rest = Comparison{
				candidate = drop (length parsed.candidate) state.rest.candidate,
				requirement }}}

takeAs :: Show t => Comparison -> t -> Parser.ParseRunner Mismatch Comparison ComparatorState t
takeAs = Parser.takeAsUsing takeAs1

takeAsNull :: Show t => t -> Parser.ParseRunner Mismatch Comparison ComparatorState t
takeAsNull = takeAs Comparison { candidate = [], requirement = [] }

compareAsCandidatePattern :: SomePattern -> Comparator
compareAsCandidatePattern (SomePattern pattern) =
	Pattern.compareAsCandidate pattern >:> comparator >\> const ()

compareAsRequirementPattern :: SomePattern -> Comparator
compareAsRequirementPattern (SomePattern pattern) =
	Pattern.compareAsRequirement pattern >:> comparator >\> const ()

startState :: Bool -> TypeTest -> SomePattern -> SomePattern -> ComparatorState
startState checkArgTypes test requirement candidate =
	ComparatorState {
		indentation = 0,
		atStart = True,
		spaceState = Code.Space,
		rest = Comparison { candidate = flat candidate, requirement = flat requirement },
		checkArgTypes,
		test }

swapCandidate :: [SomePattern] -> ComparatorState -> ComparatorState
swapCandidate newCandidate s = s{ rest = s.rest{ candidate = newCandidate }}

swapRequirement :: [SomePattern] -> ComparatorState -> ComparatorState
swapRequirement newRequirement s = s{ rest = s.rest{ requirement = newRequirement }}

acceptRest :: ParseRunner
acceptRest state = takeAs state.rest () state

acceptRequirementOnly :: [SomePattern] -> ParseRunner
acceptRequirementOnly fromRequirement = takeAs Comparison {
	candidate = [],
	requirement = fromRequirement } ()

acceptUsing :: [SomePattern] -> TypeTest -> ParseRunner
acceptUsing fromRequirement test = \state -> case state.rest.candidate of
	(next:_) -> takeAs Comparison {
		candidate = [next],
		requirement = fromRequirement } () state{ test }
	[] -> error $ "A pattern comparator attempted to accept " ++ show fromRequirement ++ " from " ++
		show state.rest.requirement ++
			", but no pattern remained in the candidate to match it to!"

accept :: [SomePattern] -> ParseRunner
accept fromRequirement = \state -> acceptUsing fromRequirement state.test state

parseAll :: Comparator -> Comparator
parseAll = (>\> const ()) . Parser.parseAllUsing takeAsNull

parseWhile :: String -> (ComparatorState -> Bool) -> Comparator -> Comparator
parseWhile desc checker pieceParser =
	Parser.parseWhileUsing takeAsNull desc checker pieceParser >\> const ()

internallySatisfies :: (ComparatorState, SomePattern) -> SomePattern -> FallibleI Mismatch Parses
internallySatisfies (state, requirement) candidate =
	swapCandidate [candidate] (swapRequirement [requirement] state) >>> comparator

compareAsRequirementDefault :: SomePattern -> Comparator
compareAsRequirementDefault self = "default requirement comparator for " ++ show self @> \state ->
	case state.rest.requirement of
		nextRequirement:requirementLeft ->
			if isOptional nextRequirement && not state.atStart then do
				let skipThenCompare = "skipping optional " ++ show nextRequirement @> \state' ->
					swapRequirement requirementLeft state' >>> comparator
				state >>> compareAsRequirementDefault self >|> skipThenCompare
			else case state.rest.candidate of
				nextCandidate:_ -> state >>> compareAsCandidatePattern nextCandidate
				[] -> Error $ LeftoverRequirement $ P.Populace nextRequirement requirementLeft
		[] -> case state.rest.candidate of
			nextCandidate:candidateLeft ->
				Error $ LeftoverCandidate $ P.Populace nextCandidate candidateLeft
			[] -> acceptRest state

comparator :: Comparator
comparator = do
	"pattern comparator" @> \state -> do
		case (state.rest.requirement, state.rest.candidate) of
			([], []) -> acceptRest state
			(requirement@(nextRequirement:requirementLeft), []) ->
				if all isOptional requirement then
					acceptRest state
				else
					Error $ LeftoverRequirement $ P.Populace nextRequirement requirementLeft
			(nextRequirement:_, _) -> state >>> compareAsRequirementPattern nextRequirement
			([], nextCandidate:_) -> state >>> compareAsCandidatePattern nextCandidate
