module Beng.Parse.Patterns.Literal (
	parse
) where

import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Parsers ((@>), Parser, PrefixState(..), State(..), takeAs, takeNone)

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

parse :: Text -> Parser Match
parse literal = "literal " ++ show literal @> \state ->
	if not $ literal `Text.isPrefixOf` state.rest then
		takeNone state
	else case state.prefixState of
		AvoidingFor _ -> takeNone state
		_ -> takeAs literal (Match.Literal literal) $
			state{ prefixState = Unneeded }