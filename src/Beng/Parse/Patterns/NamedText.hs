module Beng.Parse.Patterns.NamedText (
	canBeEmpty,
	parse
) where

import Utils.Lists (wrap)

import Beng.Parse.Parsers ((@+>), (>\>), (>/\>), Parser, State(..))
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Types.Matches (Capture(..), Match)
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Types.Patterns (Pattern(..))

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

parse :: String -> Pattern -> Parser Match
parse name subpattern = "named text " ++ wrap "\"" name @+>
	Pattern.parse subpattern >/\>
	(\s match -> s{ arguments = Map.insert name (StringCapture $ Match.getText match) s.arguments }) >\>
	Match.NamedText name