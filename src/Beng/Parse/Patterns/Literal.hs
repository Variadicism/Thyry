module Beng.Parse.Patterns.Literal (
	parse
) where

import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Parsers ((@>), Parser, State(..), takeAs, takeNone)

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

parse :: Text -> Parser Match
parse literal = "literal " ++ show literal @> \state ->
	if literal `Text.isPrefixOf` state.rest
		then takeAs literal (Match.Literal literal) state
		else takeNone state