module Beng.Types.Parse.PatternArguments (
	Argument(..),
	Arguments
) where

import Beng.Types.Locations (SomeLocation)
import {-# SOURCE #-} Beng.Types.Things (SomeParameterizedThing)

import Data.Map.Ordered (OMap)

data Argument = Argument {
	name :: String,
	argType :: SomeParameterizedThing,
	decLoc :: SomeLocation }

type Arguments = OMap String Argument
