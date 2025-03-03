module Beng.Ops.Definitions (
	Definition(..),
	Runner,
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix,
	nameAsValue
) where

import Utils.Messaging (Messagable, msg)

import qualified Beng.Ops.Declarations as Declaration
import Beng.Types.Ops.Definitions (Definition(..), Runner)

-- instances

instance Eq Definition where
	(==) d1 d2 = d1.location == d2.location

instance Show Definition where
	show definition =
		(if definition.location /= definition.declaration.location
				then show definition.location ++ ": "
				else "") ++
			show definition.declaration

instance Messagable Definition where
	msg Definition{declaration} = msg declaration

instance Ord Definition where
	compare d1 d2 = compare d1.location d2.location

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

nameAsValue :: (Definition -> String)
nameAsValue = Declaration.nameAsValue . declaration