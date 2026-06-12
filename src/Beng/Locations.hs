module Beng.Locations (
	Builtin(..),
	BuiltinArg(..),
	BuiltinProp(..),
	FileLocation(..),
	Location(..),
	SomeLocation(..)
) where

import Utils.Messaging (Messagable, msg)
import Utils.Strings (parenthesize)

import Beng.Types.Locations

import Data.List (intercalate)
import Data.Ord (comparing)
import Data.Typeable (cast)

-- instances

deriving instance Eq FileLocation

instance Show FileLocation where
	show FileLocation{..} = intercalate ":" [file, show line, show column]

instance Messagable FileLocation where
	msg FileLocation{..} = "on line " ++ show line ++ " at " ++ show column ++ " in " ++ file

instance Ord FileLocation where
	compare l1 l2 =
		comparing file l1 l2 <> comparing line l1 l2 <> comparing column l1 l2

instance Location FileLocation where
	locationTypeIndex _ = 3

deriving instance Eq Builtin

instance Show Builtin where
	show Builtin{index} = '#' : show index

instance Messagable Builtin where
	msg = show

instance Ord Builtin where
	compare = comparing (.index)

instance Location Builtin where
	locationTypeIndex _ = 0

instance Show BuiltinProp where
	show BuiltinProp{..} = '#' : show parentIndex ++ "." ++ show propIndex ++ parenthesize (msg one)

instance Messagable BuiltinProp where
	msg = show

instance Eq BuiltinProp where
	prop1 == prop2 =
		prop1.parentIndex == prop2.parentIndex &&
		prop1.propIndex == prop2.propIndex &&
		prop1.one == prop2.one

instance Ord BuiltinProp where
	compare prop1 prop2 =
		comparing (.parentIndex) prop1 prop2 <>
		comparing (.propIndex) prop1 prop2 <>
		comparing (.one) prop1 prop2

instance Location BuiltinProp where
	locationTypeIndex _ = 1

deriving instance Eq BuiltinArg

instance Show BuiltinArg where
	show BuiltinArg{name,parentIndex} = '#' : show parentIndex ++ "!" ++ name

instance Messagable BuiltinArg where
	msg = show

instance Ord BuiltinArg where
	compare arg1 arg2 = comparing (.parentIndex) arg1 arg2 <> comparing (.name) arg1 arg2

instance Location BuiltinArg where
	locationTypeIndex _ = 2

instance Eq SomeLocation where
	SomeLocation location1 == SomeLocation location2 = case cast location2 of
		Just matchingLocation2 -> location1 == matchingLocation2
		Nothing -> False

instance Show SomeLocation where
	show (SomeLocation location) = show location

instance Messagable SomeLocation where
	msg (SomeLocation location) = msg location

instance Ord SomeLocation where
	compare l1@(SomeLocation location1) l2@(SomeLocation location2) =
		comparing locationTypeIndexOf l1 l2 <> case cast location2 of
			Just matchingLocation2 -> compare location1 matchingLocation2
			Nothing -> EQ
		where
			locationTypeIndexOf (SomeLocation location) = locationTypeIndex location
