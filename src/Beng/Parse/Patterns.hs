module Beng.Parse.Patterns (
	Pattern(..),
	parse,
	parseNonPrefixed,
	getArgs,
	hasArgs,
	mustHavePrefix,
	mustHaveSuffix,
	canHavePrefix,
	canHaveSuffix,
	showWithStrings,
	showWith,
	showParensWith
) where

import Utils.Lists (takeUntilIncl)

import qualified Beng.Parse.Patterns.And as And
import qualified Beng.Parse.Patterns.Arg as Argument
import qualified Beng.Parse.Patterns.Delimited as Delimited
import qualified Beng.Parse.Patterns.Empty as Empty
import qualified Beng.Parse.Patterns.Literal as Literal
import qualified Beng.Parse.Patterns.Or as Or
import qualified Beng.Parse.Patterns.Space as Space
import qualified Beng.Parse.Arguments as Arg
import Beng.Parse.Types.Patterns (Pattern(..))
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Matches.NonPrefixed as NonPrefixed
import Beng.Parse.Parsers ((>\>), Parser, parseNone)
import Beng.Run.Types.Values (ValueType(..))
import Beng.Ops (Op)

import Data.List (intercalate)
import Data.Map ((!?), Map)
import qualified Data.Map as Map
import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text

-- instances

deriving instance Eq Pattern

instance Show Pattern where
	show = showWith Map.empty

-- exports

parse :: Pattern -> Parser Match
parse = \case
	Empty -> Empty.parse
	Space -> Space.parse
	Literal literal -> Literal.parse literal
	And subpatterns -> And.parse subpatterns
	Or subpatterns -> Or.parse subpatterns
	Delimited{..} -> Delimited.parse delimiter delimitend
	Argument{arg} -> Argument.parse arg

parseNonPrefixed :: (Pattern -> Op -> Parser NonPrefixed.Match)
parseNonPrefixed = \case
	pattern | mustHavePrefix pattern -> const parseNone
	Or{subpatterns} -> Or.parseNonPrefixed subpatterns
	And{subpatterns} -> And.parseNonPrefixed subpatterns
	Delimited{delimiter,delimitend} -> Delimited.parseNonPrefixed delimiter delimitend
	Argument{arg} -> Argument.parseNonPrefixed arg
	pattern -> const $ parse pattern >\>
		\match -> NonPrefixed.Match { argCaptured = False, match }

getArgs :: Pattern -> [Arg.Definition]
getArgs = \case
	And subpatterns ->
		map (wrapType ListType) $ concatMap getArgs subpatterns
	Or subpatterns ->
		map (wrapType MaybeType) $ concatMap getArgs subpatterns
	Delimited delimiter delimitend ->
		map (wrapType ListType) $ concatMap getArgs [delimiter, delimitend]
	Argument arg -> [arg]
	_ -> []
	where
		wrapType :: (ValueType -> ValueType) -> Arg.Definition -> Arg.Definition
		wrapType wrapper arg = arg{ Arg.valueType = wrapper arg.valueType }

hasArgs :: Pattern -> Bool
hasArgs = not . null . getArgs

mustHavePrefix :: (Pattern -> Bool)
mustHavePrefix = \case
	Empty -> False
	Space -> False
	Argument{} -> False
	Literal literal -> not $ Text.null literal
	And subpatterns ->
		any mustHavePrefix $ takeUntilIncl hasArgs subpatterns
	Or subpatterns -> all mustHavePrefix subpatterns
	Delimited _ delimitend -> mustHavePrefix delimitend

mustHaveSuffix :: (Pattern -> Bool)
mustHaveSuffix = \case
	And subpatterns ->
		any mustHaveSuffix $ takeUntilIncl hasArgs $ reverse subpatterns
	Or subpatterns -> all mustHaveSuffix subpatterns
	Delimited _ delimitend -> mustHaveSuffix delimitend
	pattern -> mustHavePrefix pattern

canHavePrefix :: (Pattern -> Bool)
canHavePrefix = \case
	Space -> True
	And subpatterns ->
		any canHavePrefix $ takeUntilIncl hasArgs subpatterns
	Or subpatterns -> any canHavePrefix subpatterns
	Delimited delimiter delimitend -> any canHavePrefix [delimiter, delimitend]
	pattern -> mustHavePrefix pattern

canHaveSuffix :: (Pattern -> Bool)
canHaveSuffix = \case
	And subpatterns ->
		any canHaveSuffix $ takeUntilIncl hasArgs $ reverse subpatterns
	Or subpatterns -> any canHaveSuffix subpatterns
	Delimited delimiter delimitend -> any canHaveSuffix [delimiter, delimitend]
	pattern -> canHavePrefix pattern

showWithStrings :: Map String String -> (Pattern -> String)
showWithStrings argStrings = \case
	Empty -> ""
	Space -> " "
	And subpatterns -> concatMap showSub subpatterns
	Or subpatterns -> "(" ++ intercalate "|" (map showSub subpatterns) ++ ")"
	Literal literal -> unpack literal
	Delimited delimiter delimitend ->
		"(" ++ showSub delimitend ++ "){" ++ showSub delimiter ++ "}"
	Argument arg -> case argStrings !? arg.name of
		Just argString -> argString
		Nothing -> show arg
	where
		showSub = showWithStrings argStrings

showWith :: Map String Op -> (Pattern -> String)
-- TODO: show parentheses around arg ops with higher precedence when needed.
showWith args = showWithStrings (Map.map show args)

showParensWith :: Map String Op -> (Pattern -> String)
showParensWith args = showWithStrings (Map.map (('(':) . (++")") . show) args)