module Beng.Parse.Patterns.Delimited (
	parse
) where

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Parsers ((>:>), (>\>), (@+>), Parser, parseAll)
import Beng.Parse.Types.Patterns (Pattern)

-- exported

parse :: Pattern -> Pattern -> Parser Match
parse delimiter delimitend = "a delimited pattern" @+>
	Pattern.parse delimitend >:>
	parseAll (Pattern.parse delimiter >:> Pattern.parse delimitend) >\>
	uncurry Match.Delimited