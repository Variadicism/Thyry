module Beng.Parse.Parsers.PatternComparator (
	startState,
	acceptRest,
	acceptUsing,
	accept,
	parseAll,
	parseWhile,
	compareFrom,
	comparator,
	module Beng.Types.Parse.Parsers.PatternComparator
) where

import Utils.Fallible
import Utils.Messaging (Messagable, msg, msgList)
import qualified Utils.Populace as P

import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>:>), (>^\>), (>|>))
import {-# SOURCE #-} qualified Beng.Parse.Parsers as Parser
import {-# SOURCE #-} qualified Beng.Parse.Patterns.And as And
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Arg as Argument
import {-# SOURCE #-} qualified Beng.Parse.Patterns.CharClass as CharClass
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Delimited as Delimited
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Literal as Literal
import {-# SOURCE #-} qualified Beng.Parse.Patterns.NamedText as NamedText
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Or as Or
import {-# SOURCE #-} qualified Beng.Parse.Patterns.Space as Space
import Beng.Types.Build.Context (Context)
import {-# SOURCE #-} Beng.Parse.Patterns (isOptional)
import Beng.Types.Parse.Parsers.PatternComparator (Comparison(..), Parse, ParseRunner, Parser, Parses, State(..))
import qualified Beng.Types.Parse.Parsers.PatternComparator as PC
import Beng.Types.Parse.Patterns (Mismatch(..), Pattern(..))

import Data.List (isPrefixOf)
import Data.Maybe (listToMaybe)

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
	show State{..} = show rest ++
		" at depth " ++ show indentation ++
		" using " ++ show context

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

-- exported

startState :: Context -> Pattern -> Pattern -> State
startState context super sub =
	State {
		indentation = 0,
		rest = Comparison { sub = flat sub, super = flat super },
		context = context }

acceptRest :: ParseRunner
acceptRest state = takeAs state.rest () state

acceptUsing :: [Pattern] -> Context -> ParseRunner
acceptUsing fromSuper context = \state -> case state.rest.sub of
	(next:_) -> takeAs Comparison { sub = [next], super = fromSuper } () state{ PC.context = context }
	[] -> error $ "A pattern comparator attempted to accept " ++ show fromSuper ++ " from " ++
		show state.rest.super ++ ", but no pattern remained in the sub to match it to!"

-- Accept the given patterns from the start of the "super" pattern to match with the next pattern from "sub".
accept :: [Pattern] -> ParseRunner
accept fromSuper = \state -> acceptUsing fromSuper state.context state

parseAll :: Parser -> Parser
parseAll = (>\> const ()) . Parser.parseAllUsing takeAsNull

parseWhile :: String -> (State -> Bool) -> Parser -> Parser
parseWhile desc checker pieceParser =
	Parser.parseWhileUsing takeAsNull desc checker pieceParser >\> const ()

compareFrom :: Pattern -> Parser
compareFrom pattern = do
	let comparatorByPattern = case pattern of
		-- I am so tired of these big fat case statements.
		-- Everyone is eager to critique inheritance,
		-- but at least this stuff comes free with it.
		Space -> Space.compareFrom
		Literal literal -> Literal.compareFrom literal
		CharClass{..} -> CharClass.compareFrom ranges negate
		NamedText{..} -> NamedText.compareFrom name subpattern decLoc
		And subpatterns -> And.compareFrom subpatterns
		Or subpatterns -> Or.compareFrom subpatterns
		Delimited delimiter delimitend -> Delimited.compareFrom delimiter delimitend
		Argument{..} -> Argument.compareFrom name argType decLoc
	let canSkip = maybe False isOptional . listToMaybe . sub . rest
	let passOptionals :: Parser = parseWhile "is optional" canSkip ("skip optional" @> accept [])
	comparatorByPattern >^\> \_ -> passOptionals >:> comparator >\> const ()

comparator :: Parser
comparator = do
	let comparator' ignoreOptional = "pattern comparator" @> \state -> do
		let swapSuper s newSuper = s{ rest = s.rest{ super = newSuper }}
		case (state.rest.super, state.rest.sub) of
			-- TODO: break up And patterns into subpatterns
			([], []) -> acceptRest state
			(super@(nextSuper:superLeft), []) ->
				if all isOptional super
					then acceptRest state
					-- `all` returns true for empty lists, so we can assume it's non-empty here.
					else Error $ LeftoverSuper $ P.Populace nextSuper superLeft
			(And{..}:superLeft, _) -> swapSuper state (subpatterns.l ++ superLeft) >>> comparator
			(NamedText{..}:superLeft, _) -> swapSuper state (subpattern:superLeft) >>> comparator
			(nextSuper:superLeft, _) | isOptional nextSuper && not ignoreOptional -> do
				let skipThenCompare = "skipping optional " ++ show nextSuper @> \state ->
					swapSuper state superLeft >>> comparator
				state >>> comparator' True >|> skipThenCompare
			(_, nextSub:_) -> state >>> compareFrom nextSub
	comparator' False