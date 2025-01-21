module Beng.Parse.Patterns.NamedText where

import Beng.Types.Locations (Location)
import Beng.Types.Parse.Matches (Match)
import qualified Beng.Types.Parse.Parsers.Code as Code
import qualified Beng.Types.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Patterns (Pattern)

parse :: String -> Pattern -> Location -> Code.Parser Match

compareFrom :: String -> Pattern -> Location -> PatternComparator.Parser