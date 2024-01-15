module Beng.Types.Ops.Declarations (
	Associativity(..),
	Declaration(..)
) where

import Beng.Parse.Types.Patterns (Pattern)

data Associativity = Lefty | Righty

data Declaration = Declaration {
	pattern :: Pattern,
	associativity :: Associativity }