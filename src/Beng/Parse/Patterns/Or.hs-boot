module Beng.Parse.Patterns.Or where

import Beng.Types.Parse.Matches (SomeMatch)
import Beng.Types.Parse.Patterns (Or, Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Or -> Code.Parser SomeMatch
instance Pattern Or
