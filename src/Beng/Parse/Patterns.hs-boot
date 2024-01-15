module Beng.Parse.Patterns where

import Beng.Parse.Types.Matches (Match)
import Beng.Parse.Types.Parsers (Parser)
import Beng.Parse.Types.Patterns (Pattern)
import Beng.Types.Ops (Op)

import Data.Map (Map)

instance Eq Pattern

instance Show Pattern

parse :: Pattern -> Parser Match

hasArgs :: Pattern -> Bool

canHavePrefix :: Pattern -> Bool

canHaveSuffix :: Pattern -> Bool

mustHavePrefix :: Pattern -> Bool

mustHaveSuffix :: Pattern -> Bool

showWithStrings :: Map String String -> Pattern -> String

showWith :: Map String Op -> Pattern -> String

showParensWith :: Map String Op -> Pattern -> String