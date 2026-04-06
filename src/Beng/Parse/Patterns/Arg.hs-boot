module Beng.Parse.Patterns.Arg where

import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Locations (Location)
import Beng.Types.Parse.Patterns (Argument, Pattern)
import Beng.Types.Things (SomeThing)
import qualified Beng.Types.Parse.Parsers.Code as Code

showArg :: String -> SomeThing -> Location -> String
msgArg :: String -> SomeThing -> String
parse :: Argument -> Code.Parser Match.Argument
instance Pattern Match.Argument Argument
