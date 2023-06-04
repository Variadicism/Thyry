module Beng.Types.OpPatterns (
	OpPattern(..)
) where

import Utils.Lists (wrap)

import Data.List (intercalate)
import Data.Text.Lazy (Text, unpack)

-- types

data OpPattern = OpEmpty |
	OpSpace |
	OpLiteral Text |
	OpOr [OpPattern] |
	OpAnd [OpPattern] |
	OpDelimited String OpPattern
	deriving (Eq)

-- instances

instance Show OpPattern where
	show OpEmpty = ""
	show OpSpace = " "
	show (OpAnd subpatterns) = concatMap show subpatterns
	show (OpOr subpatterns) = intercalate "|" $ map show subpatterns
	show (OpLiteral literal) = unpack literal
	show (OpDelimited delimiter subpattern) = "(" ++ show subpattern ++ "){" ++ wrap "\"" delimiter ++ "}"