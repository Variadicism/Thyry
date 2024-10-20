module Beng.Parse.Patterns.NamedText (
	canBeEmpty,
	parse
) where

import Utils.Lists (wrap)

import Beng.Parse.Parsers.Code ((@+>), (>\>), (>/\>), Parser, State(..))
import qualified Beng.Parse.Matches as Match
import Beng.Types.Parse.Matches (Match)
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Patterns (Pattern(..))
import Beng.Types.Locations (Location)
import Beng.Types.Values (Type(NativeStringType), Value(NativeStringValue))

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
	Argument{} -> False

parse :: String -> Pattern -> Location -> Parser Match
parse name subpattern decLoc = "named text " ++ wrap "\"" name @+>
	Pattern.parse subpattern >/\> (\s match -> do
		let parameter = Match.Parameter {
			decLoc, name, paramType = NativeStringType,
			value = NativeStringValue $ Match.toCode match }
		s{ arguments = Map.insert name parameter s.arguments }) >\> \match ->
	Match.NamedText { decLoc, name, match }