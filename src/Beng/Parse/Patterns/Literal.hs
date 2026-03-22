module Beng.Parse.Patterns.Literal (
	parse
) where

import Utils.Fallible hiding (Fallible)
import Utils.Messaging (Messagable(..))
import qualified Utils.Populace as P
import qualified Utils.Text as UtilsText

import Beng.Errors (parseError)
import Beng.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@>))
import Beng.Parse.Parsers.Code (PrefixState(..))
import qualified Beng.Parse.Parsers.Code as Code
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern)
import qualified Beng.Parse.Patterns.CharClass as CC
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Patterns (
	CharClass(..),
	Comparison(..),
	ComparatorState(..),
	Literal(..),
	Mismatch(..),
	SomePattern(..),
	Space(..))

import Data.Char (isSpace)
import qualified Data.Text.Lazy as Text

parseLiteral :: Literal -> Code.Parser Match
parseLiteral (Literal literal) = "literal " ++ show literal @> \state ->
	if not $ literal `Text.isPrefixOf` state.rest then
		Error $ parseError state $ show literal ++ " was expected next!"
	else case state.prefixState of
		AvoidingFor op -> Error $ parseError state $
			"An non-prefixed argument was expected to match " ++ show op ++ ", but a prefix was found!"
		_ -> Code.takeAs literal (Match.Literal literal)
			state{ Code.prefixState = Unneeded }

compareFromLiteral :: Literal -> PatternComparator.Parser
compareFromLiteral self@(Literal literal) = show literal ++ " comparator" @> \state ->
	if Text.null literal then
		PatternComparator.accept [] state
	else case state.rest.super of
		[] -> Error $ LeftoverSub $ P.assume state.rest.sub
		next:superLeft -> do
			let superP = P.Populace next superLeft
			let swapSub newSub s = s{ rest = s.rest{ sub = newSub }}
			let swapSuper newSuper s = s{ rest = s.rest{ super = newSuper }}
			case asPattern next :: Maybe Literal of
				Just (Literal superLiteral) | superLiteral == literal ->
					PatternComparator.accept [next] state
				Just (Literal superLiteral) | literal `Text.isPrefixOf` superLiteral -> do
					let remainingSuper = UtilsText.dropPrefix literal superLiteral
					let splitSuper = [SomePattern self, SomePattern (Literal remainingSuper)] ++ superLeft
					PatternComparator.accept [SomePattern self] $ swapSuper splitSuper state
				Just (Literal superLiteral) | superLiteral `Text.isPrefixOf` literal -> do
					let remainingSub = UtilsText.dropPrefix superLiteral literal
					let splitSub = next : SomePattern (Literal remainingSub) : tail state.rest.sub
					PatternComparator.accept [next] $ swapSub splitSub state
				_ -> case asPattern next :: Maybe CharClass of
					Just CharClass{..} | CC.has (Text.head literal) ranges negate -> do
						let splitSub = next : SomePattern (Literal (Text.tail literal)) : tail state.rest.sub
						PatternComparator.accept [next] $ swapSub splitSub state
					_ | maybe False (const True) (asPattern next :: Maybe Space)
						&& maybe False (isSpace . fst) (Text.uncons literal) -> do
							let splitSub = next : SomePattern (Literal (Text.dropWhile isSpace literal)) : tail state.rest.sub
							PatternComparator.accept [next] $ swapSub splitSub state
					_ -> Error $ Mismatch (SomePattern self) superP

instance Messagable Literal where
	msg = show

instance TPattern.Pattern Literal where
	parse = parseLiteral
	compareFrom = compareFromLiteral
	showPatternWith _ (Literal literal) = Text.unpack literal
	mustHavePrefix (Literal literal) = not $ Text.null literal
	mustHaveSuffix (Literal literal) = not $ Text.null literal
	canHavePrefix = TPattern.mustHavePrefix
	canHaveSuffix = TPattern.mustHaveSuffix
	isOptional (Literal literal) = Text.null literal

parse :: Literal -> Code.Parser Match
parse = parseLiteral
