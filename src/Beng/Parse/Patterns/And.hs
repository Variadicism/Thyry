module Beng.Parse.Patterns.And (
	parse
) where

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>:>), (>\>), Parser, takeAs)
import Beng.Parse.Types.Patterns (Pattern)

import Data.List (singleton)

-- exported

parse :: [Pattern] -> Parser Match
parse subpatterns =
	show (length subpatterns) ++ " patterns" @+>
	parseAsList subpatterns >\> Match.And
	where
		parseAsList :: [Pattern] -> Parser [Match]
		parseAsList = \case
			[] -> "Empty And" @> takeAs "" []
			[next] -> Pattern.parse next >\> singleton
			(next:rest) ->
				Pattern.parse next >:>
				parseAsList rest >\>
				\(nextMatch, restMatches) -> nextMatch:restMatches