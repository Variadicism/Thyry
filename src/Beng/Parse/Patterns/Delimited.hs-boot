module Beng.Parse.Patterns.Delimited where

import Beng.Types.Parse.Matches (Match)
import qualified Beng.Types.Parse.Parsers.Code as Code
import qualified Beng.Types.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Patterns (Pattern)

parse :: Pattern -> Pattern -> Code.Parser Match

compareFrom :: Pattern -> Pattern -> PatternComparator.Parser