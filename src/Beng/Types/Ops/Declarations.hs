module Beng.Types.Ops.Declarations (
	ArgContextsBuilder,
	Associativity(..),
	Declaration(..)
) where

import Utils.Errors

import Beng.Build.Types.Context (Context, PrecedenceBound)
import Beng.Parse.Types.Patterns (Pattern)
import {-# SOURCE #-} Beng.Types.Ops (Op)

import Data.Map (Map)

data Associativity = Lefty | Righty

type ArgContextsBuilder = Context -> Map String Op -> Fallible (Map String Context)

data Declaration = Declaration {
	pattern :: Pattern,
	associativity :: Associativity,
	precedence :: PrecedenceBound,
	buildContexts :: ArgContextsBuilder }