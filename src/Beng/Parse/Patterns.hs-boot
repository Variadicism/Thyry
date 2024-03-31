module Beng.Parse.Patterns where

import Utils.Messaging (Messagable)

import Beng.Parse.Types.Matches (Match)
import Beng.Parse.Types.Parsers (Parser)
import Beng.Parse.Types.Patterns (CharRange, Parameter, Pattern)

import Data.Map.Ordered (OMap)

instance Eq CharRange

instance Show CharRange

instance Messagable CharRange

instance Eq Parameter

instance Show Parameter

instance Messagable Parameter

instance Eq Pattern

instance Show Pattern

instance Messagable Pattern

parse :: Pattern -> Parser Match

getArgs :: Pattern -> OMap String Parameter

hasArgs :: Pattern -> Bool

canHavePrefix :: Pattern -> Bool

canHaveSuffix :: Pattern -> Bool

mustHavePrefix :: Pattern -> Bool

mustHaveSuffix :: Pattern -> Bool