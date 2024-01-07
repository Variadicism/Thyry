module Beng.Types.Declarations (
	Declaration(..)
) where

import Beng.Parse.Types.Patterns (Pattern)

data Declaration = Declaration {
	pattern :: Pattern }