module Beng.Types.Locations where

import Utils.Messaging (Messagable)
import Data.Typeable (Typeable)

class (Eq location, Ord location, Show location, Messagable location, Typeable location) =>
	Location location where
	locationTypeIndex :: location -> Int

data SomeLocation

data Builtin

data BuiltinArg

data BuiltinProp

data FileLocation
