module Beng.Types.Locations (
	Builtin(..),
	BuiltinArg(..),
	BuiltinProp(..),
	FileLocation(..),
	Location(..),
	SomeLocation(..)
) where

import Utils.Messaging (Messagable)

import Data.Typeable (Typeable)

class (Eq location, Ord location, Show location, Messagable location, Typeable location) =>
	Location location where
	locationTypeIndex :: location -> Int

data SomeLocation = forall location. Location location => SomeLocation location

data Builtin = Builtin { index :: Int }

data BuiltinArg = BuiltinArg { name :: String, parentIndex :: Int }

data BuiltinProp = BuiltinProp {
	propIndex :: Int,
	parentIndex :: Int,
	one :: SomeLocation }  -- TODO: revisit prop owner identity; using SomeLocation avoids recursive Eq for now.

data FileLocation = FileLocation {
	file :: FilePath,
	line :: Int,
	column :: Int }
