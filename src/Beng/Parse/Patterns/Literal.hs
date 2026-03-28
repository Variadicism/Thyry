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
import Beng.Parse.Parsers ((@>), (>>>))
import Beng.Parse.Parsers.Code (PrefixState(..))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (compareAsSuperDefault)
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern)
import qualified Beng.Parse.Patterns.CharClass as CC
import qualified Beng.Types.Parse.Patterns as TPattern
import qualified Beng.Types.Parse.Parsers.Code as SpaceState (SpaceState(..))
import Beng.Types.Parse.Patterns (
	CharClass(..),
	Comparison(..),
	ComparatorState(..),
	Literal(..),
	Mismatch(..),
	SomePattern(..),
	Space(..))

import Data.Char (isAlphaNum, isSpace)
import qualified Data.Set as Set
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

compareAsSubLiteral :: Literal -> PatternComparator.Parser
compareAsSubLiteral self@(Literal literal) = show literal ++ " comparator" @> \state ->
	if Text.null literal then
		PatternComparator.accept [] state
	else case state.rest.super of
		[] -> Error $ LeftoverSub $ P.assume state.rest.sub
		next:superLeft -> do
			let superP = P.Populace next superLeft
			let swapSub newSub s = s{ rest = s.rest{ sub = newSub }}
			let swapSuper newSuper s = s{ rest = s.rest{ super = newSuper }}
			case asPattern next :: Maybe Literal of
				Just (Literal superLiteral) -> if superLiteral == literal then
					PatternComparator.accept [next] state
				else if literal `Text.isPrefixOf` superLiteral then do
					let remainingSuper = UtilsText.dropPrefix literal superLiteral
					let splitSuper = [SomePattern self, SomePattern (Literal remainingSuper)] ++ superLeft
					PatternComparator.accept [SomePattern self] $ swapSuper splitSuper state
				else if superLiteral `Text.isPrefixOf` literal then do
					let remainingSub = UtilsText.dropPrefix superLiteral literal
					let splitSub = next : SomePattern (Literal remainingSub) : tail state.rest.sub
					PatternComparator.accept [next] $ swapSub splitSub state
				else
					compareAgainstNonLiteral self literal next state superP swapSub
				Nothing -> compareAgainstNonLiteral self literal next state superP swapSub

compareAsSuperLiteral :: Literal -> PatternComparator.Parser
compareAsSuperLiteral self@(Literal literal) = show literal ++ " super comparator" @> \state ->
	if Text.null literal then
		case state.rest.super of
			_:superLeft -> PatternComparator.swapSuper superLeft state >>> PatternComparator.comparator
			[] -> case state.rest.sub of
				nextSub:subLeft -> Error $ LeftoverSub $ P.Populace nextSub subLeft
				[] -> PatternComparator.acceptRest state
	else
		state >>> compareAsSuperDefault (SomePattern self)

instance Messagable Literal where
	msg = show

instance TPattern.Pattern Literal where
	parse = parseLiteral
	compareAsSub = compareAsSubLiteral
	compareAsSuper = compareAsSuperLiteral
	showPatternWith _ (Literal literal) = Text.unpack literal
	mustHavePrefix (Literal literal) = not $ Text.null literal
	mustHaveSuffix (Literal literal) = not $ Text.null literal
	canHavePrefix = TPattern.mustHavePrefix
	canHaveSuffix = TPattern.mustHaveSuffix
	canMatchEmpty (Literal literal) = Text.null literal
	startingSpaceStates (Literal literal) = if Text.null literal then
		mempty
	else do
		let headChar = Text.head literal
		Set.singleton $
			if isSpace headChar then SpaceState.Space
			else if isAlphaNum headChar then SpaceState.Word
			else SpaceState.Punctuation
	isOptional (Literal literal) = Text.null literal

compareAgainstNonLiteral
	:: Literal
	-> Text.Text
	-> SomePattern
	-> ComparatorState
	-> P.Populace SomePattern
	-> ([SomePattern] -> ComparatorState -> ComparatorState)
	-> FallibleI Mismatch PatternComparator.Parses
compareAgainstNonLiteral self literal next state superP swapSub =
	case asPattern next :: Maybe CharClass of
		Just CharClass{..} -> if CC.has (Text.head literal) ranges negate then do
			let splitSub = next : SomePattern (Literal (Text.tail literal)) : tail state.rest.sub
			PatternComparator.accept [next] $ swapSub splitSub state
		else
			compareAgainstSpace self literal next state superP swapSub
		Nothing -> compareAgainstSpace self literal next state superP swapSub

compareAgainstSpace
	:: Literal
	-> Text.Text
	-> SomePattern
	-> ComparatorState
	-> P.Populace SomePattern
	-> ([SomePattern] -> ComparatorState -> ComparatorState)
	-> FallibleI Mismatch PatternComparator.Parses
compareAgainstSpace self literal next state superP swapSub =
	case (asPattern next :: Maybe Space, Text.uncons literal) of
		(Just Space, Just (firstChar, _)) -> if isSpace firstChar then do
			let splitSub = next : SomePattern (Literal (Text.dropWhile isSpace literal)) : tail state.rest.sub
			PatternComparator.accept [next] $ swapSub splitSub state{ spaceState = SpaceState.Space }
		else
			Error $ Mismatch (SomePattern self) superP
		_ -> Error $ Mismatch (SomePattern self) superP

parse :: Literal -> Code.Parser Match
parse = parseLiteral
