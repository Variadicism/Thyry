module Beng.Parse.Patterns where

import Utils.Fallible (FallibleI, IsError)
import Utils.Messaging (Messagable)
import Utils.Populace (Populace)

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.Parsers.Code (Parser)
import Beng.Types.Parse.Patterns (CharRange, Mismatch, Parameter, Pattern)
import Beng.Types.SatisfactionTest (SatisfactionTest)

import Data.Map.Ordered (OMap)

instance Eq Mismatch

instance Show Mismatch

instance Messagable Mismatch

instance Ord Mismatch

instance IsError Mismatch

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

getSubpatterns :: Pattern -> Populace Pattern

getArgs :: Pattern -> OMap String Parameter

getRequiredArgs :: Pattern -> OMap String Parameter

hasArgs :: Pattern -> Bool

canHavePrefix :: Pattern -> Bool

canHaveSuffix :: Pattern -> Bool

mustHavePrefix :: Pattern -> Bool

mustHaveSuffix :: Pattern -> Bool

isOptional :: Pattern -> Bool

satisfies :: (SatisfactionTest, Pattern) -> Pattern -> FallibleI Mismatch ()