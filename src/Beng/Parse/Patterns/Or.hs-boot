module Beng.Parse.Patterns.Or where

import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Patterns (Or, Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Or -> Code.Parser Match.Or
instance Pattern Match.Or Or
