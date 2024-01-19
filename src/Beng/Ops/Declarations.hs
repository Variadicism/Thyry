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

import Utils.Lists (wrap)

import Beng.Build.Types.Context (PrecedenceBound(..))
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Ops.Declarations (ArgContextBuilder, Associativity(..), Declaration(..))

-- instances

deriving instance Eq Associativity

deriving instance Show Associativity

instance Eq Declaration where
	-- TODO: when OpDeclarations can be dynamic, equality will use code location.
	(==) d1 d2 = d1.pattern == d2.pattern

instance Show Declaration where
	-- TODO: when ops can be dynamically defined, replace "BUILTIN" with the code locus.
	show = ("[builtin]: "++) . wrap "`" . show . pattern

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