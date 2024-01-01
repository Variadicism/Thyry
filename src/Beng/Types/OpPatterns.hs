module Beng.Types.OpPatterns (
	OpPattern(..),
	mustBePrefix,
	mustBeSuffix,
	canBePrefix,
	canBeSuffix
) where

import Data.List (intercalate)
import Data.Text.Lazy (Text, unpack)
import qualified Data.Text.Lazy as Text

-- types

data OpPattern = OpEmpty |
	OpSpace |
	OpLiteral Text |
	OpOr [OpPattern] |
	OpAnd [OpPattern] |
	OpDelimited OpPattern OpPattern
	deriving (Eq)

-- instances

instance Show OpPattern where
	show OpEmpty = ""
	show OpSpace = " "
	show (OpAnd subpatterns) = concatMap show subpatterns
	show (OpOr subpatterns) = intercalate "|" $ map show subpatterns
	show (OpLiteral literal) = unpack literal
	show (OpDelimited delimiter subpattern) = "(" ++ show subpattern ++ "){" ++ show delimiter ++ "}"

-- exported

mustBePrefix :: OpPattern -> Bool
mustBePrefix = \case
	OpEmpty -> False
	OpSpace -> False
	OpLiteral literal -> not $ Text.null literal
	OpAnd subpatterns -> any mustBePrefix subpatterns
	OpOr subpatterns -> all mustBePrefix subpatterns
	OpDelimited _ delimitend -> mustBePrefix delimitend

mustBeSuffix :: (OpPattern -> Bool)
-- These will not be equivalent when OpArgs mix with OpPatterns.
mustBeSuffix = mustBePrefix

canBePrefix :: OpPattern -> Bool
canBePrefix pattern = mustBePrefix pattern || case pattern of
	OpAnd subpatterns -> any canBePrefix subpatterns
	OpOr subpatterns -> any canBePrefix subpatterns
	OpDelimited delimiter delimitend -> any canBePrefix [delimiter, delimitend]
	_ -> False

canBeSuffix :: (OpPattern -> Bool)
-- These will not be equivalent when OpArgs mix with OpPatterns.
canBeSuffix = mustBeSuffix