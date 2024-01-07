module Beng.Parse.Patterns.Empty (
	parse
) where

import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Parsers ((@>), Parser, takeAs)

parse :: Parser Match
parse = "empty" @> takeAs "" Match.Empty