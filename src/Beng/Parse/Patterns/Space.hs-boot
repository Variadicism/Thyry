module Beng.Parse.Patterns.Space where

import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Patterns (Pattern, Space)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Space -> Code.Parser Match.Space
instance Pattern Match.Space Space
