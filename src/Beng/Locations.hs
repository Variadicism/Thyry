module Beng.Locations (
	Location(..)
) where

import Beng.Types.Locations (Location(..))

import Data.List (intercalate)

-- instances

deriving instance Eq Location

instance Show Location where
	show Builtin{} = "[builtin]"
	show Dynamic{file,line,column} = intercalate ":" [file, show line, show column]

instance Ord Location where
	compare l1 l2 = case (l1, l2) of
		(b1@Builtin{}, b2@Builtin{}) -> compare b1.index b2.index
		(Builtin{}, Dynamic{}) -> LT
		(Dynamic{}, Builtin{}) -> GT
		(d1@Dynamic{}, d2@Dynamic{}) ->
			compare d1.file d2.file <>
			compare d1.line d2.line <>
			compare d1.column d2.column