module Beng.Build.Types.Cards (
	Card(..)
) where

import {-# SOURCE #-} Beng.Types.Ops.Declarations (Declaration)
import {-# SOURCE #-} Beng.Types.Ops.Definitions (Definition)

-- A Card represents one declaration or definition that can be used ("played"?) while parsing code.
-- I decided against aliasing Either to simplify and unify certain behaviors like Show.

data Card = DecCard Declaration | DefCard Definition