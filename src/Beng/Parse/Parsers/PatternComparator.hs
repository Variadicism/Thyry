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
import {-# SOURCE #-} qualified Beng.Parse.Patterns.And as And
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Arg as Argument
import {-# SOURCE #-} qualified Beng.Parse.Patterns.CharClass as CharClass
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Delimited as Delimited
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Literal as Literal
import {-# SOURCE #-} qualified Beng.Parse.Patterns.NamedText as NamedText
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Or as Or
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Space as Space
import Beng.Build.TypeTest (TypeTest)
import {-# SOURCE #-} Beng.Parse.Patterns (isOptional)
import Beng.Types.Parse.Parsers.PatternComparator (Comparison(..), Parse, ParseRunner, Parser, Parses, State(..))
import qualified Beng.Types.Parse.Parsers.PatternComparator as PC
import Beng.Types.Parse.Patterns (Mismatch(..), Pattern(..))

import Data.List (isPrefixOf)

-- instances

deriving instance Eq Comparison

deriving instance Eq State

instance Parser.State Comparison State where
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

instance Messagable State where
	msg State{..} = msg rest

instance Show State where
	show State{..} =
		{- Don't print the test; this state prints at every single parser step and the test prints
		   lots of info, so the logs get INCREDIBLY spammy. -}
		show rest ++ " at depth " ++ show indentation

-- private

flat :: Pattern -> [Pattern]
flat = \case
	And subpatterns -> subpatterns.l
	pattern -> [pattern]

takeAs1 :: Comparison -> t -> State -> Parser.Parse Comparison State t
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
			state = state{ rest = Comparison{
				sub = drop (length parsed.sub) state.rest.sub,
				super }}}

takeAs :: Show t => Comparison -> t -> Parser.ParseRunner Mismatch Comparison State t
takeAs = Parser.takeAsUsing takeAs1

takeAsNull :: Show t => (t -> Parser.ParseRunner Mismatch Comparison State t)
takeAsNull = takeAs Comparison { sub = [], super = [] }

compareFrom :: Pattern -> Parser
compareFrom pattern = do
	let comparatorByPattern = case pattern of
		-- I am so tired of these big fat case statements.
		-- Everyone is eager to critique inheritance,
		-- but at least this stuff comes free with it.
		Space -> Space.compareFrom
		Literal literal -> Literal.compareFrom literal
		CharClass{..} -> CharClass.compareFrom ranges negate
		NamedText{..} -> NamedText.compareFrom name subpattern
		And subpatterns -> And.compareFrom subpatterns
		Or subpatterns -> Or.compareFrom subpatterns
		Delimited delimiter delimitend -> Delimited.compareFrom delimiter delimitend
		Argument{..} -> Argument.compareFrom name argType decLoc
	comparatorByPattern >:> comparator >\> const ()

-- exported

startState :: Bool -> TypeTest -> Pattern -> Pattern -> State
startState checkArgTypes test super sub =
	State {
		indentation = 0,
		rest = Comparison { sub = flat sub, super = flat super },
		checkArgTypes,
		test }

swapSub :: [Pattern] -> State -> State
swapSub newSub s = s{ rest = s.rest{ sub = newSub }}

swapSuper :: [Pattern] -> State -> State
swapSuper newSuper s = s{ rest = s.rest{ super = newSuper }}

acceptRest :: ParseRunner
acceptRest state = takeAs state.rest () state

acceptUsing :: [Pattern] -> TypeTest -> ParseRunner
acceptUsing fromSuper test = \state -> case state.rest.sub of
	(next:_) -> takeAs Comparison { sub = [next], super = fromSuper } () state{ PC.test = test }
	[] -> error $ "A pattern comparator attempted to accept " ++ show fromSuper ++ " from " ++
		show state.rest.super ++ ", but no pattern remained in the sub to match it to!"

-- Accept the given patterns from the start of the "super" pattern to match with the next pattern from "sub".
accept :: [Pattern] -> ParseRunner
accept fromSuper = \state -> acceptUsing fromSuper state.test state

parseAll :: Parser -> Parser
parseAll = (>\> const ()) . Parser.parseAllUsing takeAsNull

parseWhile :: String -> (State -> Bool) -> Parser -> Parser
parseWhile desc checker pieceParser =
	Parser.parseWhileUsing takeAsNull desc checker pieceParser >\> const ()

internallySatisfies :: (State, Pattern) -> Pattern -> FallibleI Mismatch Parses
internallySatisfies (state, super) sub = swapSub [sub] (swapSuper [super] state) >>> comparator

comparator :: Parser
comparator = do
	let comparator' ignoreOptional = "pattern comparator" @> \state -> do
		let isNamedText = \case -- Seriously, is there no better way to do this?!
			NamedText{} -> True
			_ -> False
		let isOr = \case
			Or{} -> True
			_ -> False

		-- TODO: check all other patterns before we typecheck arguments.
		-- (Typechecks are exponentially inefficient!)
		case (state.rest.super, state.rest.sub) of
			([], []) -> acceptRest state
			(super@(nextSuper:superLeft), []) ->
				if all isOptional super
					then acceptRest state
					-- `all` returns true for empty lists, so we can assume it's non-empty here.
					else Error $ LeftoverSuper $ P.Populace nextSuper superLeft
			(And{..}:superLeft, _) -> swapSuper (subpatterns.l ++ superLeft) state >>> comparator
			(Or{..}:superLeft, sub) | null sub || not (isOr $ head sub) -> do
				{- Ors in the super position need to be handled as subpatterns, but if this happens before
					Or.compareFrom, then Or.compareFrom tries to match each of the sub Or's subpatterns to
					ALL of the super Or's subpatterns when in reality, only ONE of the super Or's subpatterns
					needs to satisfy each of the sub Or's subpatterns. -}
				let parserFor i option =
					"possible super pattern " ++ show (i + 1) ++ "/" ++ show (length subpatterns) ++
							" " ++ show option @> \state ->
						swapSuper (option:superLeft) state >>> comparator
				state >>> (parseAny $ P2.toP1 $ P2.mapIndexed parserFor subpatterns)
			(nt@NamedText{..}:superLeft, sub) | null sub || not (isNamedText $ head sub) -> do
				{- Supers don't need to capture all the NamedTexts that the sub does.
					But, if both are NamedTexts, they must be compared without "unnaming" because
					while the super doesn't have to capture the same things, if it does, they need
					to have the same name. -}
				swapSuper (nt.subpattern:superLeft) state >>> comparator
			(Literal "":superLeft, _) ->
				{- Ignore empties entirely. If not for this case, it would tee off the empty as an optional,
				   trying to parse with and without accepting the empty, which is just
				   pointless, inefficient, and log-muddying. -}
				swapSuper superLeft state >>> comparator
			(nextSuper:superLeft, _) | isOptional nextSuper && not ignoreOptional -> do
				let skipThenCompare = "skipping optional " ++ show nextSuper @> \state ->
					swapSuper superLeft state >>> comparator
				state >>> comparator' True >|> skipThenCompare
			(_, nextSub:_) -> state >>> compareFrom nextSub
	comparator' False