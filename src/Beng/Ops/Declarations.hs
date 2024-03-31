module Beng.Ops.Declarations (
	ArgContextBuilder,
	Associativity(..),
	Declaration(..),
	PrecedenceBound(..),
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix,
	nameAsValue
) where

import Utils.Messaging (Messagable, msg)

import Beng.Build.Types.Context (PrecedenceBound(..))
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Types.Patterns (Pattern(Literal))
import Beng.Locations ()
import Beng.Ops.Types.Declarations (ArgContextBuilder, Associativity(..), Declaration(..))
import {-# SOURCE #-} Beng.Values ()

import Control.Exception.Extra (Partial)
import Data.Text.Lazy (unpack)
import GHC.Records (HasField, getField)

-- instances

deriving instance Eq Associativity

deriving instance Show Associativity

instance Eq Declaration where
	(==) d1 d2 = d1.location == d2.location

instance Show Declaration where
	show dec = show dec.location ++ "\\" ++ msg dec.pattern ++ " => " ++ show dec.returnType

instance Messagable Declaration where
	msg Declaration{pattern} = msg pattern

instance HasField "name" Declaration String where
	getField = nameAsValue

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

nameAsValue :: Partial => Declaration -> String
nameAsValue declaration = do
	let (Literal name) = declaration.pattern
	unpack name