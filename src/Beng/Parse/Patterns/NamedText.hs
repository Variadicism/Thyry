module Beng.Parse.Patterns.NamedText (
	canBeEmpty,
	parse
) where

import Utils.Fallible
import Utils.Lists (wrap)
import Utils.Messaging (Messagable(..), msg)
import qualified Utils.Populace as P

import Beng.Locations ()
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>\>), (>/\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (internallySatisfies)
import qualified Beng.Parse.Parsers.PatternComparator as PC
import Beng.Parse.Parsers.PatternComparator (comparator)
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
canBeEmpty = Pattern.isOptional

parseNamedText :: NamedText -> Code.Parser Match
parseNamedText NamedText{..} = "named text " ++ wrap "\"" name @+>
	Pattern.parse subpattern >/\> (\s match -> do
		let argument = Match.Argument {
			decLoc, name, argType = NativeStringType,
			value = NativeStringValue $ Match.toCode match }
		s{ Code.arguments = Map.insert name argument s.arguments }) >\> \match ->
	Match.NamedText { decLoc, name, match }

compareFromNamedText :: NamedText -> PC.Parser
compareFromNamedText NamedText{..} = "named text " ++ wrap "\"" name ++ " comparator" @> \state ->
	case state.rest.super of
		(next:superLeft) | Just nt@NamedText{} <- (asPattern next :: Maybe NamedText) ->
			if nt.name == name then do
				(state, nt.subpattern) `internallySatisfies` subpattern
				PC.accept [next] state
			else
				Error $ Mismatch next $ P.Populace next superLeft
		_ -> state{ rest = state.rest{ sub = subpattern : tail state.rest.sub }} >>> comparator

instance Eq NamedText where
	a == b = a.name == b.name && a.subpattern == b.subpattern && a.decLoc == b.decLoc

instance Show NamedText where
	show NamedText{..} = wrap "\"" name ++ "(" ++ show subpattern ++ ")"

instance Messagable NamedText where
	msg NamedText{..} = wrap "\"" name ++ "(" ++ msg subpattern ++ ")"

instance TPattern.Pattern NamedText where
	parse = parseNamedText
	compareFrom = compareFromNamedText
	showPatternWith useMsg NamedText{..} =
		wrap "\"" name ++ "(" ++ (if useMsg then msg subpattern else show subpattern) ++ ")"
	mustHavePrefix NamedText{..} = not $ canBeEmpty subpattern
	mustHaveSuffix = TPattern.mustHavePrefix
	canHavePrefix _ = True
	canHaveSuffix _ = True
	isOptional NamedText{..} = Pattern.isOptional subpattern
	getSubpatterns NamedText{..} = P.singleton subpattern
	getArgsUsing getArgs NamedText{..} =
		(name, Argument { name, decLoc, argType = NativeStringType }) OMap.|< getArgs subpattern

parse :: NamedText -> Code.Parser Match
parse = parseNamedText
