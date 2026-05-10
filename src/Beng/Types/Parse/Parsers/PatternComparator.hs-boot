module Beng.Types.Parse.Parsers.PatternComparator where

import {-# SOURCE #-} Beng.Types.Parse.Patterns (Mismatch)
import qualified Beng.Types.Parse.Parsers as General

data Comparison
data ComparatorState

type State = ComparatorState
type Parse = General.Parse Comparison ComparatorState ()
type Parses = General.Parses Mismatch Comparison ComparatorState ()
type ParseRunner = General.ParseRunner Mismatch Comparison ComparatorState ()
type Comparator = General.Parser Mismatch Comparison ComparatorState ()
