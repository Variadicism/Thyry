module Beng.Parse.Patterns (
	specials,
	CharRange(..),
	Parameter(..),
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
import Utils.Messaging (Messagable, msg)
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
import Beng.Types.Parse.Patterns (CharRange(..), Parameter(..), Pattern(..))
import Beng.Parse.Matches (Match)
import Beng.Parse.Parsers.Code (Parser)
import Beng.Types.Locations (Location)
import Beng.Types.Values (Type(..))

import Data.List (intercalate)
import Data.Map.Ordered ((<>|), OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text

-- constants

-- ^ and $ are not applicable in Literal patterns.
specials = ".{}[] "

-- instances

deriving instance Eq CharRange

instance Show CharRange where
	show CharRange{start,end} =
		if start == end
			then escape CharClass.specials [start]
			else escape CharClass.specials [start] ++ "-" ++ escape CharClass.specials [end]

instance Messagable CharRange where
	msg = show

instance Eq Parameter where
	(==) p1 p2 = p1.name == p2.name

instance Show Parameter where
	show Parameter{name,paramType,decLoc} = showParam name paramType decLoc

instance Messagable Parameter where
	msg Parameter{name,paramType} = msgParam name paramType

deriving instance Eq Pattern

instance Show Pattern where
	show = showPatternWith show

instance Messagable Pattern where
	-- In the future, I might show simplified versions of some patterns or a simple subset of the pattern here.
	msg = \case
		Argument{name,argType} -> msgParam name argType
		p -> showPatternWith msg p

-- private

showPatternWith :: (Pattern -> String) -> Pattern -> String
showPatternWith show = \case
	Space -> " "
	Literal literal -> unpack literal
	CharClass{ranges,negate} -> CharClass.showClass ranges negate
	NamedText{name,subpattern} -> wrap "\"" name ++ parenthesize (show subpattern)
	And subpatterns -> concatMap show subpatterns
	Or subpatterns -> parenthesize $ intercalate "|" $ map show subpatterns.l
	Delimited delimiter delimitend ->
		-- TODO: determine if parentheses are necessary based on precedence.
		parenthesize (show delimitend) ++ "{" ++ show delimiter ++ "}"
	Argument{name,argType,decLoc} -> showParam name argType decLoc
	

msgParam :: String -> Type -> String
msgParam name paramType = wrap "'" $ name ++ ", " ++ msg paramType

showParam :: String -> Type -> Location -> String
showParam name paramType decLoc = show decLoc ++ ":" ++ msgParam name paramType

-- exports

parse :: Pattern -> Parser Match
parse = \case
	Space -> Space.parse
	Literal literal -> Literal.parse literal
	CharClass{ranges,negate} -> CharClass.parse ranges negate
	NamedText{name,subpattern,decLoc} -> NamedText.parse name subpattern decLoc
	And subpatterns -> And.parse subpatterns
	Or subpatterns -> Or.parse subpatterns
	Delimited{delimiter,delimitend} -> Delimited.parse delimiter delimitend
	Argument{name,argType,decLoc} -> Argument.parse name argType decLoc

getSubpatterns :: Pattern -> Populace Pattern
getSubpatterns = \case
	NamedText{subpattern} -> P.singleton subpattern
	And subpatterns -> subpatterns.p1
	Or subpatterns -> subpatterns.p1
	Delimited{..} -> P.Populace delimitend [delimiter]
	pattern -> P.singleton pattern

getArgs :: Pattern -> OMap String Parameter
getArgs = \case
	NamedText{decLoc,name} -> OMap.singleton (name,
		Parameter { decLoc, name, paramType = NativeStringType })
	And subpatterns -> OMap.concat $ map getArgs subpatterns.l
	Or subpatterns ->
		wrapTypes NativeOptionalType $ OMap.concat $ map getArgs subpatterns.l
	Delimited delimiter delimitend ->
		(wrapTypes NativeSomeType $ getArgs delimiter) <>|
		(wrapTypes NativeListType $ getArgs delimitend)
	Argument{decLoc,name,argType} -> OMap.singleton (name,
		Parameter { decLoc, name, paramType = argType })
	_ -> OMap.empty
	where
		wrapTypes :: (Type -> Type) -> OMap String Parameter -> OMap String Parameter
		wrapTypes wrapper = OMap.map (\p -> p{ paramType = wrapper p.paramType })

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