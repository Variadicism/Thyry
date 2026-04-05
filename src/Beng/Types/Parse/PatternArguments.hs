module Beng.Types.Parse.PatternArguments (
	Argument(..),
	Arguments
) where

import Beng.Types.Locations (Location)
import {-# SOURCE #-} Beng.Types.Things (SomeThing)

import Data.Map.Ordered (OMap)

data Argument = Argument {
	name :: String,
	argType :: SomeThing,
	decLoc :: Location }

type Arguments = OMap String Argument
