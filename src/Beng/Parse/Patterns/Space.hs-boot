module Beng.Parse.Patterns.Space where

import Beng.Types.Parse.Matches (Match)
import qualified Beng.Types.Parse.Parsers.Code as Code
import qualified Beng.Types.Parse.Parsers.PatternComparator as PatternComparator

parse :: Code.Parser Match

compareFrom :: PatternComparator.Parser
