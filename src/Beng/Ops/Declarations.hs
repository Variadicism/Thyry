module Beng.Ops.Declarations (
	ArgContextBuilder,
	Associativity(..),
	Declaration(..),
	PrecedenceBound(..),
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix
) where

import Beng.Build.Types.Context (PrecedenceBound(..))
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Locations ()
import Beng.Types.Ops.Declarations (ArgContextBuilder, Associativity(..), Declaration(..))

-- instances

deriving instance Eq Associativity

deriving instance Show Associativity

instance Eq Declaration where
	(==) d1 d2 = d1.location == d2.location

instance Show Declaration where
	show declaration = show declaration.location ++ ": " ++ show declaration.pattern

-- exported

isNullary :: (Declaration -> Bool)
isNullary = not . Pattern.hasArgs . pattern

canHavePrefix :: Declaration -> Bool
canHavePrefix = Pattern.canHavePrefix . pattern

canHaveSuffix :: Declaration -> Bool
canHaveSuffix = Pattern.canHaveSuffix . pattern

mustHavePrefix :: Declaration -> Bool
mustHavePrefix = Pattern.mustHavePrefix . pattern

mustHaveSuffix :: Declaration -> Bool
mustHaveSuffix = Pattern.mustHaveSuffix . pattern