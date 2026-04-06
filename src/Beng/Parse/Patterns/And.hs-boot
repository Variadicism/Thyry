module Beng.Parse.Patterns.And where

import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Patterns (And, Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: And -> Code.Parser Match.And
instance Pattern Match.And And
