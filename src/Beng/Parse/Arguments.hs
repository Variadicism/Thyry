module Beng.Parse.Arguments (
	Definition(..),
	Match(..)
) where

import Utils.Lists (wrap)

import Beng.Parse.Types.Arguments (Definition(..), Match(..))

-- instances

instance Eq Definition where
	(==) arg1 arg2 = arg1.name == arg2.name

instance Show Definition where
	show arg = wrap "'" arg.name

instance Ord Definition where
	(<=) arg1 arg2 = arg1.name <= arg2.name

instance Eq Match where
	(==) m1 m2 = m1.definition == m2.definition