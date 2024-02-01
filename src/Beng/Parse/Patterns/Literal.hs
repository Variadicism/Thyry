module Beng.Parse.Patterns.Literal (
	parse
) where

import Utils.Fallible hiding (Fallible)

import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import Beng.Parse.Parsers ((@>), Parser, PrefixState(..), State(..), takeAs)
import Beng.Types.Errors (Error(ParseError))

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

parse :: Text -> Parser Match
parse literal = "literal " ++ show literal @> \state ->
	if not $ literal `Text.isPrefixOf` state.rest then
		Error $ ParseError state $ show literal ++ " was expected next!"
	else case state.prefixState of
		AvoidingFor op -> Error $ ParseError state $
			"An non-prefixed argument was expected to match " ++ show op ++ ", but a prefix was found!"
		_ -> takeAs literal (Match.Literal literal)
			state{ prefixState = Unneeded }