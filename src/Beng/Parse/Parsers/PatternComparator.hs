module Beng.Parse.Parsers.PatternComparator (
	startState,
	swapSub,
	swapSuper,
	acceptRest,
	acceptUsing,
	accept,
	parseAll,
	parseWhile,
	internallySatisfies,
	comparator,
	module Beng.Types.Parse.Parsers.PatternComparator
) where

import Utils.Fallible
import Utils.Messaging (Messagable, msg, msgList)
import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2

import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>:>), (>|>), parseAny)
import {-# SOURCE #-} qualified Beng.Parse.Parsers as Parser
import Beng.Build.TypeTest (TypeTest)
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern, isOptional, startingSpaceStates)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Parsers.PatternComparator (Comparison(..), Parse, ParseRunner, Parser, Parses)
import Beng.Types.Parse.Patterns (And(..), ComparatorState(..), Literal(..), Mismatch(..), NamedText(..), Or(..), SomePattern(..), Space(..))
import qualified Beng.Types.Parse.Patterns as TPattern

import Control.Applicative ((<|>))
import Data.List (isPrefixOf)
import qualified Data.Set as Set
import qualified Data.Text.Lazy as Text

deriving instance Eq Comparison
deriving instance Eq ComparatorState

instance Parser.State Comparison ComparatorState where
	rest = rest
	indentation = indentation
	indent s = s{ indentation = s.indentation + 1 }
	outdent s = s{ indentation = s.indentation - 1 }

instance Messagable Comparison where
	msg Comparison{..} = msgList sub ++ " in? " ++ msgList super

instance Show Comparison where
	show Comparison{..} = show sub ++ " in? " ++ show super

instance Ord Comparison where
	compare c1 c2 = compare (length c1.sub) (length c1.sub) <> compare (length c2.super) (length c2.super)

instance Semigroup Comparison where
	a <> b = Comparison { sub = a.sub ++ b.sub, super = a.super ++ b.super }

instance Messagable ComparatorState where
	msg ComparatorState{..} = msg rest

instance Show ComparatorState where
	show ComparatorState{..} = show rest ++ " at depth " ++ show indentation

spaceStateOfLiteral :: SomePattern -> Maybe Code.SpaceState
spaceStateOfLiteral pattern = do
	Literal literal <- asPattern pattern
	if Text.null literal
		then Nothing
		else Just $ Code.spaceStateOfChar $ Text.last literal

comparisonSpaceState :: Comparison -> Maybe Code.SpaceState
comparisonSpaceState Comparison{..} = do
	let ofPatterns patterns = foldl (\acc pattern -> acc <|> spaceStateOfLiteral pattern) Nothing $ reverse patterns
	ofPatterns sub <|> ofPatterns super

canSatisfyBoundaryBefore :: ComparatorState -> [SomePattern] -> Bool
canSatisfyBoundaryBefore state = \case
	next:_ -> do
		let states = startingSpaceStates next
		not (Set.null states) && all (Code.formsBoundary state.spaceState) states
	[] -> False

canConsumeWhitespace :: SomePattern -> Bool
canConsumeWhitespace = Set.member Code.Space . startingSpaceStates

flat :: SomePattern -> [SomePattern]
flat pattern = case asPattern pattern of
	Just (And subpatterns) -> subpatterns.l
	Nothing -> [pattern]

takeAs1 :: Comparison -> t -> ComparatorState -> Parser.Parse Comparison ComparatorState t
takeAs1 parsed target state =
	if not $ parsed.sub `isPrefixOf` state.rest.sub && parsed.super `isPrefixOf` state.rest.super then
		error $ "A pattern comparator illegally requested that " ++ show parsed.sub ++
			" should be accepted from " ++ show state.rest.sub ++ " (sub) and " ++ show parsed.super ++
			" from " ++ show state.rest.super ++ " (super)!"
	else do
		let super = case drop (length parsed.super) state.rest.super of
			nextSuper:superLeft -> flat nextSuper ++ superLeft
			newSuper -> newSuper
		Parser.Parse {
			parsed,
			target,
			state = state{
				atStart = False,
				spaceState = maybe state.spaceState id $ comparisonSpaceState parsed,
				rest = Comparison{
				sub = drop (length parsed.sub) state.rest.sub,
				super }}}

takeAs :: Show t => Comparison -> t -> Parser.ParseRunner Mismatch Comparison ComparatorState t
takeAs = Parser.takeAsUsing takeAs1

takeAsNull :: Show t => t -> Parser.ParseRunner Mismatch Comparison ComparatorState t
takeAsNull = takeAs Comparison { sub = [], super = [] }

compareFromPattern :: SomePattern -> Parser
compareFromPattern (SomePattern pattern) = TPattern.compareFrom pattern >:> comparator >\> const ()

startState :: Bool -> TypeTest -> SomePattern -> SomePattern -> ComparatorState
startState checkArgTypes test super sub =
	ComparatorState {
		indentation = 0,
		atStart = True,
		spaceState = Code.Space,
		rest = Comparison { sub = flat sub, super = flat super },
		checkArgTypes,
		test }

swapSub :: [SomePattern] -> ComparatorState -> ComparatorState
swapSub newSub s = s{ rest = s.rest{ sub = newSub }}

swapSuper :: [SomePattern] -> ComparatorState -> ComparatorState
swapSuper newSuper s = s{ rest = s.rest{ super = newSuper }}

acceptRest :: ParseRunner
acceptRest state = takeAs state.rest () state

acceptUsing :: [SomePattern] -> TypeTest -> ParseRunner
acceptUsing fromSuper test = \state -> case state.rest.sub of
	(next:_) -> takeAs Comparison { sub = [next], super = fromSuper } () state{ test }
	[] -> error $ "A pattern comparator attempted to accept " ++ show fromSuper ++ " from " ++
		show state.rest.super ++ ", but no pattern remained in the sub to match it to!"

accept :: [SomePattern] -> ParseRunner
accept fromSuper = \state -> acceptUsing fromSuper state.test state

parseAll :: Parser -> Parser
parseAll = (>\> const ()) . Parser.parseAllUsing takeAsNull

parseWhile :: String -> (ComparatorState -> Bool) -> Parser -> Parser
parseWhile desc checker pieceParser =
	Parser.parseWhileUsing takeAsNull desc checker pieceParser >\> const ()

internallySatisfies :: (ComparatorState, SomePattern) -> SomePattern -> FallibleI Mismatch Parses
internallySatisfies (state, super) sub = swapSub [sub] (swapSuper [super] state) >>> comparator

comparator :: Parser
comparator = do
	let comparator' ignoreOptional = "pattern comparator" @> \state -> do
		let isNamedText = maybe False (const True) . (asPattern :: SomePattern -> Maybe NamedText)
		let isOr = maybe False (const True) . (asPattern :: SomePattern -> Maybe Or)
		let isSpacePattern = maybe False (const True) . (asPattern :: SomePattern -> Maybe Space)
		let asAnd = asPattern :: SomePattern -> Maybe And
		let asLiteral = asPattern :: SomePattern -> Maybe Literal
		let continueOrCompare nextSuper superLeft = if isOptional nextSuper && not state.atStart && not ignoreOptional then do
				let skipThenCompare = "skipping optional " ++ show nextSuper @> \state' ->
					swapSuper superLeft state' >>> comparator
				state >>> comparator' True >|> skipThenCompare
			else case state.rest.sub of
				nextSub:_ -> state >>> compareFromPattern nextSub
				[] -> error "Pattern comparator reached continueOrCompare without a remaining subpattern."

		case (state.rest.super, state.rest.sub) of
			([], []) -> acceptRest state
			(super@(nextSuper:superLeft), []) -> if all isOptional super then
				acceptRest state
			else
				Error $ LeftoverSuper $ P.Populace nextSuper superLeft
			(nextSuper:superLeft, sub) -> case asAnd nextSuper of
				Just (And subpatterns) ->
					swapSuper (subpatterns.l ++ superLeft) state >>> comparator
				Nothing -> case asPattern nextSuper :: Maybe Or of
					Just (Or subpatterns) -> if null sub || not (isOr $ head sub) then do
							let parserFor i option =
								"possible super pattern " ++ show (i + 1) ++ "/" ++ show (length subpatterns) ++
										" " ++ show option @> \state' ->
									swapSuper (option:superLeft) state' >>> comparator
							state >>> parseAny (P2.toP1 $ P2.mapIndexed parserFor subpatterns)
						else
							state >>> compareFromPattern (head sub)
					Nothing -> case asPattern nextSuper :: Maybe NamedText of
						Just nt@NamedText{} -> if null sub || not (isNamedText $ head sub) then
							swapSuper (nt.subpattern:superLeft) state >>> comparator
						else
							state >>> compareFromPattern (head sub)
						Nothing -> case asLiteral nextSuper of
							Just (Literal "") -> swapSuper superLeft state >>> comparator
							_ -> case asPattern nextSuper :: Maybe Space of
								Just Space -> do
									let headSubIsSpace = not (null sub) && isSpacePattern (head sub)
									let headSubConsumesWhitespace = not (null sub) && canConsumeWhitespace (head sub)
									let canConsumeBoundary =
										not headSubIsSpace &&
										not headSubConsumesWhitespace &&
										not state.atStart &&
										canSatisfyBoundaryBefore state superLeft
									if canConsumeBoundary then
										state >>> ("consume boundary super Space" @>
												takeAs Comparison { sub = [], super = [nextSuper] } ()) >:>
											comparator >\> const ()
									else
										continueOrCompare nextSuper superLeft
								Nothing -> continueOrCompare nextSuper superLeft
			(_, nextSub:_) -> state >>> compareFromPattern nextSub
	comparator' False
