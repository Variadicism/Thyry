module Beng.Parse.Patterns.Space where

import Beng.Types.Parse.Matches (SomeMatch)
import Beng.Types.Parse.Patterns (Pattern, Space)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Space -> Code.Parser SomeMatch
instance Pattern Space
