module Beng.Types.Parse.Patterns (
	Mismatch(..),
	CharRange(..),
	Parameter(..),
	Pattern(..)
) where

import Utils.Populace (Populace)
import Utils.Populace.Populace2 (Populace2)

import Beng.Types.Locations (Location)
import {-# SOURCE #-} Beng.Types.Values (Type)

import Data.Text.Lazy (Text)

data Mismatch =
	-- \/ closest to success
	LeftoverSuper { leftover :: Populace Pattern } |
	LeftoverSub { leftover :: Populace Pattern } |
	Mismatch { nextSub :: Pattern, remainingSuper :: Populace Pattern } |
	-- /\ furthest from success
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

-- I could implement this with Haskell ranges, but I want to Show them nicely.
data CharRange = CharRange { start :: Char, end :: Char }

data Parameter = Parameter { name :: String, paramType :: Type, decLoc :: Location }

data Pattern =
	Space |
	Literal { literal :: Text } |
	CharClass { ranges :: Populace CharRange, negate :: Bool } |
	NamedText { name :: String, subpattern :: Pattern, decLoc :: Location } |
	Or { subpatterns :: Populace2 Pattern } |
	And { subpatterns :: Populace2 Pattern } |
	-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me! :P
	Delimited { delimiter :: Pattern, delimitend :: Pattern } |
	Argument { name :: String, argType :: Type, decLoc :: Location }