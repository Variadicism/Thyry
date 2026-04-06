module Beng.Parse.Patterns.NamedText where

import Beng.Types.Parse.Matches (SomeMatch)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Patterns (NamedText, Pattern, SomePattern)

canBeEmpty :: SomePattern -> Bool

parse :: NamedText -> Code.Parser SomeMatch
instance Pattern NamedText
