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
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Parsers.PatternComparator (Comparison(..), Parse, ParseRunner, Parser, Parses)
import Beng.Types.Parse.Patterns (And(..), ComparatorState(..), Literal(..), Mismatch(..), NamedText(..), Or(..), SomePattern(..))
import qualified Beng.Types.Parse.Patterns as TPattern

import Data.List (isPrefixOf)

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

flat :: SomePattern -> [SomePattern]
flat pattern = case TPattern.asPattern pattern of
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
		let isNamedText = maybe False (const True) . (TPattern.asPattern :: SomePattern -> Maybe NamedText)
		let isOr = maybe False (const True) . (TPattern.asPattern :: SomePattern -> Maybe Or)
		let asAnd = TPattern.asPattern :: SomePattern -> Maybe And
		let asLiteral = TPattern.asPattern :: SomePattern -> Maybe Literal

		case (state.rest.super, state.rest.sub) of
			([], []) -> acceptRest state
			(super@(nextSuper:superLeft), []) ->
				if all Pattern.isOptional super
					then acceptRest state
					else Error $ LeftoverSuper $ P.Populace nextSuper superLeft
			(nextSuper:superLeft, _) | Just (And subpatterns) <- asAnd nextSuper ->
				swapSuper (subpatterns.l ++ superLeft) state >>> comparator
			(nextSuper:superLeft, sub)
				| Just (Or subpatterns) <- (TPattern.asPattern nextSuper :: Maybe Or)
				, null sub || not (isOr $ head sub) -> do
				let parserFor i option =
					"possible super pattern " ++ show (i + 1) ++ "/" ++ show (length subpatterns) ++
							" " ++ show option @> \state' ->
						swapSuper (option:superLeft) state' >>> comparator
				state >>> (parseAny $ P2.toP1 $ P2.mapIndexed parserFor subpatterns)
			(nextSuper:superLeft, sub)
				| Just nt@NamedText{} <- (TPattern.asPattern nextSuper :: Maybe NamedText)
				, null sub || not (isNamedText $ head sub) ->
				swapSuper (nt.subpattern:superLeft) state >>> comparator
			(nextSuper:superLeft, _) | Just (Literal "") <- asLiteral nextSuper ->
				swapSuper superLeft state >>> comparator
			(nextSuper:superLeft, _)
				| Pattern.isOptional nextSuper && not state.atStart && not ignoreOptional -> do
				let skipThenCompare = "skipping optional " ++ show nextSuper @> \state' ->
					swapSuper superLeft state' >>> comparator
				state >>> comparator' True >|> skipThenCompare
			(_, nextSub:_) -> state >>> compareFromPattern nextSub
	comparator' False
