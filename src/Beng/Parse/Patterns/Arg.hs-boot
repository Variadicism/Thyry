module Beng.Parse.Patterns.Arg where

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Locations (Location)
import Beng.Types.Values (Type)
import qualified Beng.Types.Parse.Parsers.Code as Code
import qualified Beng.Types.Parse.Parsers.PatternComparator as PatternComparator

parse :: String -> Type -> Location -> Code.Parser Match

compareFrom :: String -> Type -> Location -> PatternComparator.Parser