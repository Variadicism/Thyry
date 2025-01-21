module Beng.Parse.Patterns.Literal (
	parse,
	compareFrom
) where

import Utils.Fallible hiding (Fallible)
import qualified Utils.Populace as P
import qualified Utils.Text as T

import Beng.Errors (parseError)
import Beng.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@>))
import Beng.Parse.Parsers.Code (PrefixState(..))
import qualified Beng.Parse.Parsers.Code as Code
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import qualified Beng.Parse.Parsers.PatternComparator as PC
import Beng.Types.Parse.Patterns (Mismatch(..), Pattern(Literal))

import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

parse :: Text -> Code.Parser Match
parse literal = "literal " ++ show literal @> \state ->
	if not $ literal `Text.isPrefixOf` state.rest then
		Error $ parseError state $ show literal ++ " was expected next!"
	else case state.prefixState of
		AvoidingFor op -> Error $ parseError state $
			"An non-prefixed argument was expected to match " ++ show op ++ ", but a prefix was found!"
		_ -> Code.takeAs literal (Match.Literal literal)
			state{ Code.prefixState = Unneeded }

compareFrom :: Text -> PatternComparator.Parser
compareFrom literal = show literal ++ " comparator" @> \state -> case state.rest.super of
	[] -> Error $ LeftoverSub $ P.assume state.rest.sub  -- Sub must start with the pattern being parsed.
	next:superLeft -> do
		let self = Literal literal
		let superP = P.Populace next superLeft
		case next of
			Literal nextLiteral | nextLiteral `Text.isPrefixOf` literal ->
				if literal == nextLiteral then
					PC.accept [next] state
				else do
					let remainingText = T.dropPrefix nextLiteral literal
					PC.accept [next] state{ PC.rest = state.rest{
						PC.super = [self, Literal remainingText] ++ superLeft }}
			_ -> Error $ Mismatch self superP