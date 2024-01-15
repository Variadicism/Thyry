module Beng.Ops.Definitions (
	Definition(..),
	ArgContextsBuilder,
	Runner,
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix,
	showParensWith,
	showWith,
	showWithStrings
) where

import qualified Beng.Ops.Declarations as Declaration
import Beng.Types.Ops.Definitions (Definition(..), ArgContextsBuilder, Runner)
import Beng.Types.Ops (Op)

import Data.Map (Map)

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

-- TODO: when ops can be dynamically defined, modify the "show" functions to reflect locus info.
showParensWith :: Map String Op -> (Definition -> String)
showParensWith args = Declaration.showParensWith args . declaration

showWith :: Map String Op -> (Definition -> String)
showWith args = Declaration.showWith args . declaration

showWithStrings :: Map String String -> (Definition -> String)
showWithStrings argStrings = Declaration.showWithStrings argStrings . declaration
