module Beng.Parse.Patterns.Or where

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.Patterns (Or, Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Or -> Code.Parser Match
instance Pattern Or
