module Beng.Parse.Patterns.NamedText (
	canBeEmpty,
	parse,
	compareFrom
) where

import Utils.Fallible
import Utils.Lists (wrap)
import qualified Utils.Populace as P

import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>\>), (>/\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (internallySatisfies)
import qualified Beng.Parse.Parsers.PatternComparator as PC
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Parse.Parsers.PatternComparator (comparator)
import qualified Beng.Parse.Matches as Match
import Beng.Types.Parse.Matches (Match)
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Patterns (Mismatch(..), Pattern(..)) 
import Beng.Types.Locations (Location)
import Beng.Types.Things (Thing(NativeStringType), Thing(NativeStringValue))

import qualified Data.Map as Map
import qualified Data.Text.Lazy as Text

canBeEmpty :: Pattern -> Bool
canBeEmpty = \case
	Space -> True
	Literal literal -> Text.null literal
	CharClass{} -> False
	NamedText{subpattern} -> canBeEmpty subpattern
	And subpatterns -> all canBeEmpty subpatterns
	Or subpatterns -> any canBeEmpty subpatterns
	Delimited{delimitend} -> canBeEmpty delimitend
	ArgP{} -> False

parse :: String -> Pattern -> Location -> Code.Parser Match
parse name subpattern decLoc = "named text " ++ wrap "\"" name @+>
	Pattern.parse subpattern >/\> (\s match -> do
		let argument = Match.Argument {
			decLoc, name, argType = NativeStringType,
			value = NativeStringValue $ Match.toCode match }
		s{ Code.arguments = Map.insert name argument s.arguments }) >\> \match ->
	Match.NamedText { decLoc, name, match }

compareFrom :: String -> Pattern -> PatternComparator.Parser
compareFrom name subpattern = "named text " ++ wrap "\"" name ++ " comparator" @> \state ->
	case state.rest.super of
		nt@NamedText{}:superLeft ->
			if nt.name == name then do
				(state, nt.subpattern) `internallySatisfies` subpattern
				PC.accept [nt] state
			else
				Error $ Mismatch nt $ P.Populace nt superLeft
		_ -> state{ PC.rest = state.rest{ PC.sub = subpattern:(tail state.rest.sub) }} >>> comparator