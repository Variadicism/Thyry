module Beng.Parse.Patterns.NamedText where

import qualified Beng.Types.Parse.Matches as Match
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Patterns (NamedText, Pattern, SomePattern)

canBeEmpty :: SomePattern -> Bool

parse :: NamedText -> Code.Parser Match.NamedText
instance Pattern Match.NamedText NamedText
