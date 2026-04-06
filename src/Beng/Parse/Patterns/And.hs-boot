module Beng.Parse.Patterns.And where

import Beng.Types.Parse.Matches (SomeMatch)
import Beng.Types.Parse.Patterns (And, Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code

parse :: And -> Code.Parser SomeMatch
instance Pattern And
