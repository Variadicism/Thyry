module Beng.Parse.Patterns.Or where

import Utils.Populace.Populace2 (Populace2)

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.Patterns (Pattern)
import qualified Beng.Types.Parse.Parsers.Code as Code
import qualified Beng.Types.Parse.Parsers.PatternComparator as PatternComparator

parse :: Populace2 Pattern -> Code.Parser Match

compareFrom :: Populace2 Pattern -> PatternComparator.Parser