module Beng.Parse.Patterns.Delimited where

import Beng.Types.Parse.Matches (Match)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Patterns (Delimited, Pattern)

parse :: Delimited -> Code.Parser Match
instance Pattern Delimited
