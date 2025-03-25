module Beng.Parse.Patterns where

import Utils.Fallible (FallibleI, IsError)
import Utils.Messaging (Messagable)
import Utils.Populace (Populace)

import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.Parsers.Code (Parser)
import Beng.Types.Parse.Patterns (CharRange, Mismatch, Argument, Pattern)
import Beng.Types.Build.TypeTest (TypeTest)

import Data.Map.Ordered (OMap)

instance Eq Mismatch

instance Show Mismatch

instance Messagable Mismatch

instance Ord Mismatch

instance IsError Mismatch

instance Eq CharRange

instance Show CharRange

instance Messagable CharRange

instance Eq Argument

instance Show Argument

instance Messagable Argument

instance Eq Pattern

instance Show Pattern

instance Messagable Pattern

parse :: Pattern -> Parser Match

getSubpatterns :: Pattern -> Populace Pattern

getArgs :: Pattern -> OMap String Argument

getRequiredArgs :: Pattern -> OMap String Argument

hasArgs :: Pattern -> Bool

canHavePrefix :: Pattern -> Bool

canHaveSuffix :: Pattern -> Bool

mustHavePrefix :: Pattern -> Bool

mustHaveSuffix :: Pattern -> Bool

isOptional :: Pattern -> Bool

satisfies :: (TypeTest, Pattern) -> Pattern -> FallibleI Mismatch ()