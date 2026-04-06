module Beng.Parse.Patterns.Arg where

import Beng.Types.Parse.Matches (SomeMatch)
import Beng.Types.Locations (Location)
import Beng.Types.Parse.Patterns (ArgP, Pattern)
import Beng.Types.Things (SomeThing)
import qualified Beng.Types.Parse.Parsers.Code as Code

showArg :: String -> SomeThing -> Location -> String
msgArg :: String -> SomeThing -> String
parse :: ArgP -> Code.Parser SomeMatch
instance Pattern ArgP
