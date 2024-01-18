module Beng.Parse.Patterns (
	Pattern(..),
	parse,
	getArgs,
	hasArgs,
	mustHavePrefix,
	mustHaveSuffix,
	canHavePrefix,
	canHaveSuffix
) where

import Utils.Lists (takeUntilIncl, wrap)
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

import Data.List (intercalate)
import Data.Map.Ordered ((<>|), OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text

-- instances

deriving instance Eq Pattern

instance Show Pattern where
	show = \case
		Space -> " "
		And subpatterns -> concatMap show subpatterns
		Or subpatterns -> "(" ++ intercalate "|" (map show subpatterns) ++ ")"
		Literal literal -> unpack literal
		Delimited delimiter delimitend ->
			"(" ++ show delimitend ++ "){" ++ show delimiter ++ "}"
		Argument{name} -> wrap "'" name

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
	And subpatterns -> foldl (<>|) OMap.empty $ map getArgs subpatterns
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