module Beng.Parse.Patterns where

import Beng.Parse.Types.Matches (Match)
import Beng.Parse.Types.Parsers (Parser)
import Beng.Parse.Types.Patterns (Pattern)
import Beng.Run.Types.Values (ValueType)

import Data.Map.Ordered (OMap)

instance Eq Pattern

instance Show Pattern

parse :: Pattern -> Parser Match

getArgs :: Pattern -> OMap String ValueType

hasArgs :: Pattern -> Bool

canHavePrefix :: Pattern -> Bool

canHaveSuffix :: Pattern -> Bool

mustHavePrefix :: Pattern -> Bool

mustHaveSuffix :: Pattern -> Bool