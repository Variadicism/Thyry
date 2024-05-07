module Beng.Parse.Patterns where

import Utils.Messaging (Messagable)

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.Parsers (Parser)
import Beng.Types.Parse.Patterns (CharRange, Parameter, Pattern)

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