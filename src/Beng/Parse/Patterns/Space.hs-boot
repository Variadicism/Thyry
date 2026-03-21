module Beng.Parse.Patterns.Space where

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.Patterns (Pattern, Space)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Space -> Code.Parser Match
instance Pattern Space
