module Beng.Parse.Patterns (
	specials,
	ArgumentType(..),
	CharRange(..),
	Pattern(..),
	parse,
	getSubpatterns,
	getArgs,
	hasArgs,
	mustHavePrefix,
	mustHaveSuffix,
	canHavePrefix,
	canHaveSuffix
) where

import Utils.Lists (takeUntilIncl, wrap)
import qualified Utils.Maps.Ordered as OMap
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Strings (escape, parenthesize)

import qualified Beng.Parse.Patterns.And as And
import qualified Beng.Parse.Patterns.Arg as Argument
import qualified Beng.Parse.Patterns.CharClass as CharClass
import qualified Beng.Parse.Patterns.Delimited as Delimited
import qualified Beng.Parse.Patterns.Literal as Literal
import qualified Beng.Parse.Patterns.NamedText as NamedText
import qualified Beng.Parse.Patterns.Or as Or
import qualified Beng.Parse.Patterns.Space as Space
import Beng.Parse.Types.Patterns (ArgumentType(..), CharRange(..), Pattern(..))
import Beng.Parse.Matches (Match)
import Beng.Parse.Parsers (Parser)

import Data.List (intercalate)
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text

-- constants

-- ^ and $ are not applicable in Literal patterns.
specials = ".{}[] "

-- instances

instance Show ArgumentType where
	show = \case
		OpType -> "op"
		StringType -> "string"
		ListType{element} -> "[" ++ show element ++ "]"
		MaybeType{inner} -> show inner ++ "?"

deriving instance Eq ArgumentType

deriving instance Eq CharRange

instance Show CharRange where
	show CharRange{start,end} =
		if start == end
			then escape CharClass.specials [start]
			else escape CharClass.specials [start] ++ "-" ++ escape CharClass.specials [end]

deriving instance Eq Pattern

instance Show Pattern where
	show = \case
		Space -> " "
		Literal literal -> unpack literal
		CharClass{ranges,negate} -> CharClass.showClass ranges negate
		NamedText{name,subpattern} -> wrap "\"" name ++ parenthesize (show subpattern)
		And subpatterns -> concatMap show subpatterns
		Or subpatterns -> parenthesize $ intercalate "|" $ map show subpatterns.l
		Delimited delimiter delimitend ->
			-- TODO: determine if parnehteses are necessary based on precedence.
			parenthesize (show delimitend) ++ "{" ++ show delimiter ++ "}"
		Argument{name} -> wrap "'" name

-- exports

parse :: Pattern -> Parser Match
parse = \case
	Space -> Space.parse
	Literal literal -> Literal.parse literal
	CharClass{ranges,negate} -> CharClass.parse ranges negate
	NamedText{name,subpattern} -> NamedText.parse name subpattern
	And subpatterns -> And.parse subpatterns
	Or subpatterns -> Or.parse subpatterns
	Delimited{..} -> Delimited.parse delimiter delimitend
	Argument{name} -> Argument.parse name

getSubpatterns :: Pattern -> Populace Pattern
getSubpatterns = \case
	NamedText{subpattern} -> P.singleton subpattern
	And subpatterns -> subpatterns.p1
	Or subpatterns -> subpatterns.p1
	Delimited{..} -> P.Populace delimitend [delimiter]
	pattern -> P.singleton pattern

getArgs :: Pattern -> OMap String ArgumentType
getArgs = \case
	NamedText{name} -> OMap.singleton (name, StringType)
	And subpatterns -> OMap.concat $ map getArgs subpatterns.l
	Or subpatterns ->
		wrapTypes MaybeType $ map getArgs subpatterns.l
	Delimited delimiter delimitend ->
		wrapTypes ListType $ map getArgs [delimiter, delimitend]
	Argument{name} -> OMap.singleton (name, OpType)
	_ -> OMap.empty
	where
		wrapTypes ::
			(ArgumentType -> ArgumentType) -> [OMap String ArgumentType] -> OMap String ArgumentType
		wrapTypes wrapper = OMap.map wrapper . OMap.concat

hasArgs :: Pattern -> Bool
hasArgs = not . null . getArgs

mustHavePrefix :: (Pattern -> Bool)
mustHavePrefix = \case
	Space -> False
	Literal literal -> not $ Text.null literal
	CharClass{} -> True
	NamedText{subpattern} -> not $ NamedText.canBeEmpty subpattern
	And subpatterns ->
		any mustHavePrefix $ takeUntilIncl hasArgs subpatterns.l
	Or subpatterns -> all mustHavePrefix subpatterns
	Delimited _ delimitend -> mustHavePrefix delimitend
	Argument{} -> False

mustHaveSuffix :: (Pattern -> Bool)
mustHaveSuffix = \case
	And subpatterns ->
		any mustHaveSuffix $ takeUntilIncl hasArgs $ reverse subpatterns.l
	Or subpatterns -> all mustHaveSuffix subpatterns.l
	Delimited _ delimitend -> mustHaveSuffix delimitend
	pattern -> mustHavePrefix pattern

canHavePrefix :: (Pattern -> Bool)
canHavePrefix = \case
	Space -> True
	NamedText{} -> True
	And subpatterns ->
		any canHavePrefix $ takeUntilIncl hasArgs subpatterns.l
	Or subpatterns -> any canHavePrefix subpatterns
	Delimited delimiter delimitend -> any canHavePrefix [delimiter, delimitend]
	pattern -> mustHavePrefix pattern

canHaveSuffix :: (Pattern -> Bool)
canHaveSuffix = \case
	And subpatterns ->
		any canHaveSuffix $ takeUntilIncl hasArgs $ reverse subpatterns.l
	Or subpatterns -> any canHaveSuffix subpatterns
	Delimited delimiter delimitend -> any canHaveSuffix [delimiter, delimitend]
	pattern -> canHavePrefix pattern