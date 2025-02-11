module Beng.Parse.Patterns.Arg where

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Locations (Location)
import Beng.Types.Things (Thing)
import qualified Beng.Types.Parse.Parsers.Code as Code
import qualified Beng.Types.Parse.Parsers.PatternComparator as PatternComparator

parse :: String -> Thing -> Location -> Code.Parser Match

compareFrom :: String -> Thing -> Location -> PatternComparator.Parser