module Beng.Parse.Patterns (
	Pattern(..),
	parse,
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

import Utils.Lists (takeUntilIncl, wrap)
import Utils.Strings (parenthesize)
import Utils.Tuples (mapSnd2)

import qualified Beng.Parse.Patterns.And as And
import qualified Beng.Parse.Patterns.Arg as Argument
import qualified Beng.Parse.Patterns.Delimited as Delimited
import qualified Beng.Parse.Patterns.Literal as Literal
import qualified Beng.Parse.Patterns.Or as Or
import qualified Beng.Parse.Patterns.Space as Space
import Beng.Parse.Types.Patterns (Pattern(..))
import Beng.Parse.Matches (Match)
import Beng.Parse.Parsers (Parser)
import Beng.Run.Values (ValueType(..))
import Beng.Ops (Op, isNullary)

import Data.List (intercalate)
import Data.Map ((!?), Map)
import qualified Data.Map as Map
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text

-- instances

deriving instance Eq Pattern

instance Show Pattern where
	show = showWith Map.empty

-- exports

parse :: Pattern -> Parser Match
parse = \case
	Space -> Space.parse
	Literal literal -> Literal.parse literal
	And subpatterns -> And.parse subpatterns
	Or subpatterns -> Or.parse subpatterns
	Delimited{..} -> Delimited.parse delimiter delimitend
	Argument{name,valueType} -> Argument.parse name valueType

getArgs :: Pattern -> OMap String ValueType
getArgs = \case
	And subpatterns ->
		wrapTypes ListType $ map getArgs subpatterns
	Or subpatterns ->
		wrapTypes MaybeType $ map getArgs subpatterns
	Delimited delimiter delimitend ->
		wrapTypes ListType $ map getArgs [delimiter, delimitend]
	Argument{name,valueType} -> OMap.singleton (name, valueType)
	_ -> OMap.empty
	where
		wrapTypes :: (ValueType -> ValueType) -> [OMap String ValueType] -> OMap String ValueType
		wrapTypes wrapper = OMap.fromList . map (mapSnd2 wrapper) . concatMap OMap.assocs

hasArgs :: Pattern -> Bool
hasArgs = not . null . getArgs

mustHavePrefix :: (Pattern -> Bool)
mustHavePrefix = \case
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
	Space -> " "
	And subpatterns -> concatMap showSub subpatterns
	Or subpatterns -> "(" ++ intercalate "|" (map showSub subpatterns) ++ ")"
	Literal literal -> unpack literal
	Delimited delimiter delimitend ->
		"(" ++ showSub delimitend ++ "){" ++ showSub delimiter ++ "}"
	Argument{name} -> case argStrings !? name of
		Just argString -> argString
		Nothing -> wrap "'" name
	where
		showSub = showWithStrings argStrings

showWith :: Map String Op -> (Pattern -> String)
-- TODO: show parentheses around arg ops with higher precedence when needed.
showWith args = showWithStrings (Map.map show args)

showParensWith :: Map String Op -> (Pattern -> String)
showParensWith args = showWithStrings (Map.map showArg args)
	where
		showArg :: Op -> String
		showArg op = if isNullary op
			then show op
			else parenthesize $ show op