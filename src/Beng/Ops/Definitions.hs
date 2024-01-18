module Beng.Ops.Definitions (
	Definition(..),
	Runner,
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix
) where

import qualified Beng.Ops.Declarations as Declaration
import Beng.Types.Ops.Definitions (Definition(..), Runner)

-- instances

instance Eq Definition where
	(==) d1 d2 = d1.declaration == d2.declaration

instance Show Definition where
	show = show . declaration

-- exported

isNullary :: (Definition -> Bool)
isNullary = Declaration.isNullary . declaration

canHavePrefix :: (Definition -> Bool)
canHavePrefix = Declaration.canHavePrefix . declaration

canHaveSuffix :: (Definition -> Bool)
canHaveSuffix = Declaration.canHaveSuffix . declaration

mustHavePrefix :: (Definition -> Bool)
mustHavePrefix = Declaration.mustHavePrefix . declaration

mustHaveSuffix :: (Definition -> Bool)
mustHaveSuffix = Declaration.mustHaveSuffix . declaration
