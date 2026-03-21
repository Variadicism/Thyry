module Beng.Types.Parse.Parsers.PatternComparator (
	Comparison(..),
	State,
	Parse,
	Parses,
	ParseRunner,
	Parser
) where

import Beng.Types.Parse.Patterns (Comparison(..))
import Beng.Types.Parse.Patterns (ComparatorState)
import Beng.Types.Parse.Patterns (ComparatorParse)
import Beng.Types.Parse.Patterns (ComparatorParses)
import Beng.Types.Parse.Patterns (ComparatorRunner)
import Beng.Types.Parse.Patterns (Comparator)

type State = ComparatorState
type Parse = ComparatorParse
type Parses = ComparatorParses
type ParseRunner = ComparatorRunner
type Parser = Comparator
