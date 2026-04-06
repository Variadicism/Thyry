module Beng.Parse.Patterns.Literal where

import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Patterns (Literal, Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Literal -> Code.Parser Match.Literal
instance Pattern Match.Literal Literal
