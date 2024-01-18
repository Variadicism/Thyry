module Beng.Types.Ops.Declarations (
	ArgContextsBuilder,
	Associativity(..),
	Declaration(..)
) where

import Utils.Errors

import Beng.Build.Types.Cards (Card)
import Beng.Build.Types.Context (PrecedenceBound)
import Beng.Parse.Types.Matches (Capture)
import Beng.Parse.Types.Patterns (Pattern)

import Data.Map (Map)

data Associativity = Lefty | Righty

type ArgContextsBuilder = Map String Capture -> Fallible (Map String [Card])

data Declaration = Declaration {
	pattern :: Pattern,
	associativity :: Associativity,
	precedence :: PrecedenceBound,
	buildContexts :: ArgContextsBuilder }