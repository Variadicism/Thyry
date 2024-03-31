module Beng.Ops.Types.Definitions (
	Definition(..),
	Runner
) where

import Beng.Ops.Types.Declarations (Declaration)
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (Location)
import Beng.Values.Types (Value)

import Data.Map (Map)

type Runner = Map String Value -> Fallible Value

data Definition = Definition {
	location :: Location,  -- Forward declarations may make this different from declaration's.
	declaration :: Declaration,
	runWith :: Runner }