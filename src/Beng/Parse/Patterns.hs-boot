module Beng.Parse.Patterns where

import Utils.Fallible (FallibleI, IsError)
import Utils.Messaging (Messagable)
import Utils.Populace (Populace)

import Beng.Types.Parse.Matches (SomeMatch)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Parsers.Code (Parser)
import Beng.Types.Parse.Patterns (Argument, CharRange, Mismatch, Pattern, SomePattern)
import Beng.Types.Build.TypeTest (TypeTest)

import Data.Map.Ordered (OMap)
import Data.Set (Set)

instance Eq Mismatch
instance Show Mismatch
instance Messagable Mismatch
instance Ord Mismatch
instance IsError Mismatch

instance Eq CharRange
instance Show CharRange
instance Messagable CharRange

instance Eq SomePattern
instance Show SomePattern
instance Messagable SomePattern

instance Eq Argument
instance Show Argument
instance Messagable Argument

asPattern :: Pattern m p => SomePattern -> Maybe p
parse :: SomePattern -> Parser SomeMatch
getSubpatterns :: SomePattern -> Populace SomePattern
getArgs :: SomePattern -> OMap String Argument
getRequiredArgs :: SomePattern -> OMap String Argument
hasArgs :: SomePattern -> Bool
canHavePrefix :: SomePattern -> Bool
canHaveSuffix :: SomePattern -> Bool
mustHavePrefix :: SomePattern -> Bool
mustHaveSuffix :: SomePattern -> Bool
canMatchEmpty :: SomePattern -> Bool
startingSpaceStates :: SomePattern -> Set Code.SpaceState
isOptional :: SomePattern -> Bool
satisfies ::
	(TypeTest, SomePattern) ->
	SomePattern ->
	FallibleI Mismatch TypeTest
