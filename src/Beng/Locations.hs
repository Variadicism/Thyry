module Beng.Locations (
	FileLocation(..),
	Location(..)
) where

import Utils.Messaging (Messagable, msg)

import Beng.Types.Locations (FileLocation(..), Location(..))

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
	show (Code fileLocation) = show fileLocation

instance Messagable Location where
	msg Builtin{} = "builtin"
	msg BuiltinArg{name} = "builtin arg " ++ show name
	msg (Code fileLocation) = msg fileLocation

instance Ord Location where
	compare l1 l2 = case (l1, l2) of
		(b1@Builtin{}, b2@Builtin{}) -> comparing index b1 b2
		(d1@Code{}, d2@Code{}) -> comparing fileLocation d1 d2
		(a1@BuiltinArg{}, a2@BuiltinArg{}) ->
			comparing parentIndex a1 a2 <> comparing name a1 a2
		(Builtin{}, BuiltinArg{}) -> LT
		(BuiltinArg{}, Builtin{}) -> GT
		(BuiltinArg{}, Code{}) -> LT
		(Code{}, BuiltinArg{}) -> GT
		(Builtin{}, Code{}) -> LT
		(Code{}, Builtin{}) -> GT