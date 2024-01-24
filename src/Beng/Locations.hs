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