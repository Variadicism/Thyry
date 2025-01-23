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
import qualified Beng.Parse.Patterns.CharClass as CC
import Beng.Types.Parse.Patterns (Mismatch(..), Pattern(CharClass, Literal, negate, ranges))

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
compareFrom literal = show literal ++ " comparator" @> \state ->
	if Text.null literal then
		PC.accept [] state
	else case state.rest.super of
		[] -> Error $ LeftoverSub $ P.assume state.rest.sub  -- Sub must start with the pattern being parsed.
		next:superLeft -> do
			let self = Literal literal
			let superP = P.Populace next superLeft
			let swapSub newSub state = state{ PC.rest = state.rest{ PC.sub = newSub }}
			let swapSuper newSuper state = state{ PC.rest = state.rest{ PC.super = newSuper }}
			case next of
				Literal superLiteral | superLiteral == literal -> PC.accept [next] state
				Literal superLiteral | literal `Text.isPrefixOf` superLiteral -> do
					let remainingSuper = T.dropPrefix literal superLiteral 
					let splitSuper = Literal literal : Literal remainingSuper : superLeft
					PC.accept [Literal literal] $ swapSuper splitSuper state
				Literal superLiteral | superLiteral `Text.isPrefixOf` literal -> do
					let remainingSub = T.dropPrefix superLiteral literal
					-- `tail` is safe because sub must start with the pattern being parsed.
					let splitSub = next : Literal remainingSub : tail state.rest.sub
					PC.accept [next] $ swapSub splitSub state
				-- Text.head is safe because null literals are already accounted for at the top.
				CharClass{..} | CC.has (Text.head literal) ranges negate -> do
					-- `tail` is safe because sub must start with the pattern being parsed.
					let splitSub = next : Literal (Text.tail literal) : tail state.rest.sub
					PC.accept [next] $ swapSub splitSub state
				_ -> Error $ Mismatch self superP