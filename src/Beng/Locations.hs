module Beng.Locations (
	FileLocation(..),
	Location(..)
) where

import Utils.Messaging (Messagable, msg)
import Utils.Strings (parenthesize)

import Beng.Types.Locations (FileLocation(..), Location(..))
import {-# SOURCE #-} Beng.Things ()

import Data.List (intercalate)
import Data.Ord (comparing)

-- instances

deriving instance Eq FileLocation

instance Show FileLocation where
	show FileLocation{..} = intercalate ":" [file, show line, show column]

instance Messagable FileLocation where
	msg FileLocation{..} = "on line " ++ show line ++ " at " ++ show column ++ " in " ++ file

instance Ord FileLocation where
	compare l1 l2 =
		comparing file l1 l2 <> comparing line l1 l2 <> comparing column l1 l2

deriving instance Eq Location

instance Show Location where
	show Builtin{index} = '#' : show index
	show BuiltinArg{name,parentIndex} = '#' : show parentIndex ++ "!" ++ name
	show BuiltinProp{..} = '#' : show parentIndex ++ "." ++ show propIndex ++ parenthesize (msg one)
	show (Code fileLocation) = show fileLocation

instance Messagable Location where
	msg = \case
		Code fileLocation -> msg fileLocation
		l -> show l

instance Ord Location where
	compare l1 l2 = case (l1, l2) of
		(b1@Builtin{}, b2@Builtin{}) -> comparing index b1 b2
		(p1@BuiltinProp{}, p2@BuiltinProp{}) ->
			comparing parentIndex p1 p2 <> comparing propIndex p1 p2
		(a1@BuiltinArg{}, a2@BuiltinArg{}) ->
			comparing parentIndex a1 a2 <> comparing name a1 a2
		(d1@Code{}, d2@Code{}) -> comparing fileLocation d1 d2
		-- disparate
		(l1, l2) -> comparing typeIndex l1 l2
		where typeIndex = \case
			Builtin{} -> 0
			BuiltinProp{} -> 1
			BuiltinArg{} -> 2
			Code{} -> 3