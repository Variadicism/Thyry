module Beng.Parse.Patterns.NamedText (
	canBeEmpty,
	parse
) where

import Utils.Fallible
import Utils.Lists (wrap)
import Utils.Messaging (Messagable(..), msg)
import qualified Utils.Populace as P

import Beng.Locations ()
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>:>), (>\>), (>/\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (internallySatisfies)
import Beng.Parse.Parsers.PatternComparator (comparator)
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import qualified Beng.Parse.Matches as Match
import Beng.Types.Parse.Matches (Match)
import Beng.Parse.Patterns (asPattern)
import qualified Beng.Parse.Patterns as Pattern
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Patterns (
	Argument(..),
	Comparison(..),
	ComparatorState(..),
	Mismatch(..),
	NamedText(..),
	SomePattern(..))
import Beng.Types.Things (Thing(NativeStringType), Thing(NativeStringValue))

import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap

canBeEmpty :: SomePattern -> Bool
canBeEmpty = Pattern.canMatchEmpty

parseNamedText :: NamedText -> Code.Parser Match
parseNamedText NamedText{..} = "named text " ++ wrap "\"" name @+>
	Pattern.parse subpattern >/\> (\s match -> do
		let argument = Match.Argument {
			decLoc, name, argType = NativeStringType,
			value = NativeStringValue $ Match.toCode match }
		s{ Code.arguments = Map.insert name argument s.arguments }) >\> \match ->
	Match.NamedText { decLoc, name, match }

compareAsSubNamedText :: NamedText -> PatternComparator.Parser
compareAsSubNamedText NamedText{..} = "named text " ++ wrap "\"" name ++ " comparator" @> \state ->
	case state.rest.sub of
		_:subLeft -> case state.rest.super of
			next:superLeft -> case asPattern next :: Maybe NamedText of
				Just nt@NamedText{} -> if nt.name == name then do
						(state, nt.subpattern) `internallySatisfies` subpattern
						PatternComparator.accept [next] state
					else
						Error $ Mismatch next $ P.Populace next superLeft
				Nothing -> state{ rest = state.rest{ sub = subpattern : subLeft }} >>> comparator
			_ -> state{ rest = state.rest{ sub = subpattern : subLeft }} >>> comparator
		[] -> case state.rest.super of
			next:superLeft -> do
				let self = NamedText { name, subpattern, decLoc }
				Error $ Mismatch (SomePattern self) $ P.Populace next superLeft
			[] -> PatternComparator.acceptRest state

compareAsSuperNamedText :: NamedText -> PatternComparator.Parser
compareAsSuperNamedText nt@NamedText{..} = "named text " ++ wrap "\"" name ++ " super comparator" @> \state ->
	case state.rest.sub of
		nextSub:_ -> case asPattern nextSub :: Maybe NamedText of
			Just NamedText{} -> dispatchCurrentSub nextSub state
			Nothing -> exposeSubpattern nt state
		[] -> exposeSubpattern nt state
	where
		dispatchCurrentSub (SomePattern pattern) state =
			state >>> TPattern.compareAsSub pattern >:> comparator >\> const ()

		exposeSubpattern NamedText{..} state = case state.rest.super of
			_:superLeft -> state{ rest = state.rest{ super = subpattern:superLeft }} >>> comparator
			[] -> case state.rest.sub of
				nextSub:subLeft -> Error $ LeftoverSub $ P.Populace nextSub subLeft
				[] -> PatternComparator.acceptRest state

instance Eq NamedText where
	a == b = a.name == b.name && a.subpattern == b.subpattern && a.decLoc == b.decLoc

instance Show NamedText where
	show NamedText{..} = wrap "\"" name ++ "(" ++ show subpattern ++ ")"

instance Messagable NamedText where
	msg NamedText{..} = wrap "\"" name ++ "(" ++ msg subpattern ++ ")"

instance TPattern.Pattern NamedText where
	parse = parseNamedText
	compareAsSub = compareAsSubNamedText
	compareAsSuper = compareAsSuperNamedText
	showPatternWith useMsg NamedText{..} =
		wrap "\"" name ++ "(" ++ (if useMsg then msg subpattern else show subpattern) ++ ")"
	mustHavePrefix NamedText{..} = not $ canBeEmpty subpattern
	mustHaveSuffix = TPattern.mustHavePrefix
	canHavePrefix _ = True
	canHaveSuffix _ = True
	canMatchEmpty NamedText{..} = Pattern.canMatchEmpty subpattern
	startingSpaceStates NamedText{..} = Pattern.startingSpaceStates subpattern
	isOptional NamedText{..} = Pattern.isOptional subpattern
	getSubpatterns NamedText{..} = P.singleton subpattern
	getArgsUsing getArgs NamedText{..} =
		(name, Argument { name, decLoc, argType = NativeStringType }) OMap.|< getArgs subpattern

parse :: NamedText -> Code.Parser Match
parse = parseNamedText
