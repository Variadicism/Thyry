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
import Beng.Types.Locations (Location)

import Data.Map (Map)

data Associativity = Lefty | Righty

type ArgContextBuilder = String -> Map String Capture -> Location -> Fallible [Card]

data Declaration = Declaration {
	location :: Location,
	pattern :: Pattern,
	associativity :: Associativity,
	precedence :: PrecedenceBound,
	contextualize :: ArgContextBuilder }