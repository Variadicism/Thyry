module Beng.Types.Operators.Declarations where

import {-# SOURCE #-} Beng.Types.Operators (SomeOperator)
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (SomeLocation)
import qualified Beng.Types.Parse.Matches as Match

import Data.Map (Map)

data Associativity

data Mismatch

data Declaration

type ArgContextBuilder =
	String -> Map String Match.Argument -> SomeLocation -> Fallible [SomeOperator]
