module Beng.Types.Ops.Definitions (
	Definition(..),
	Runner
) where

import Beng.Types.Ops.Declarations (Declaration)
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (Location)
import Beng.Types.Values (Value)

import Data.Map (Map)

type Runner = Map String Value -> Fallible Value

data Definition = Definition {
	location :: Location,  -- Forward declarations may make this different from declaration's.
	declaration :: Declaration,
	runWith :: Runner }