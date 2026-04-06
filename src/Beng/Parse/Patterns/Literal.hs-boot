module Beng.Parse.Patterns.Literal where

import Beng.Types.Parse.Matches (SomeMatch)
import Beng.Types.Parse.Patterns (Literal, Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: Literal -> Code.Parser SomeMatch
instance Pattern Literal
