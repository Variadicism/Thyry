module Beng.Types.Ops.Declarations (
	ArgContextBuilder,
	Associativity(..),
	Declaration(..)
) where

import Utils.Fallible

import Beng.Build.Types.Cards (Card)
import Beng.Build.Types.Context (PrecedenceBound)
import Beng.Parse.Types.Matches (Capture)
import Beng.Parse.Types.Patterns (Pattern)

import Data.Map (Map)

data Associativity = Lefty | Righty

type ArgContextBuilder = String -> Map String Capture -> Fallible [Card]

data Declaration = Declaration {
	pattern :: Pattern,
	associativity :: Associativity,
	precedence :: PrecedenceBound,
	contextualize :: ArgContextBuilder }