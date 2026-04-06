module Beng.Parse.Patterns.Delimited where

import qualified Beng.Types.Parse.Matches as Match
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Patterns (Delimited, Pattern)

parse :: Delimited -> Code.Parser Match.Delimited
instance Pattern Match.Delimited Delimited
