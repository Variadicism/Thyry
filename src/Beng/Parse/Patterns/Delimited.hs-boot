module Beng.Parse.Patterns.Delimited where

import Beng.Types.Parse.Matches (SomeMatch)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Patterns (Delimited, Pattern)

parse :: Delimited -> Code.Parser SomeMatch
instance Pattern Delimited
