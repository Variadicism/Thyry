module Beng.Parse.Patterns.Literal where

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.Patterns (Literal, Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Literal -> Code.Parser Match
instance Pattern Literal
