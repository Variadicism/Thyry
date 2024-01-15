module Beng.Ops.Declarations (
	Associativity(..),
	Declaration(..),
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix,
	showParensWith,
	showWith,
	showWithStrings
) where

import Utils.Lists (wrap)

import Beng.Types.Ops (Op)
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Ops.Declarations (Associativity(..), Declaration(..))

import Data.Map (Map)

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

showParensWith :: Map String Op -> Declaration -> String
showParensWith args = Pattern.showParensWith args . pattern

showWith :: Map String Op -> Declaration -> String
showWith args = Pattern.showWith args . pattern

showWithStrings :: Map String String -> Declaration -> String
showWithStrings argStrings = Pattern.showWithStrings argStrings . pattern
