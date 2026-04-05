module Beng.Types.Operators.Definitions (
	Definition(..),
	Runner
) where

import Beng.Types.Operators.Declarations (Declaration)
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (Location)
import Beng.Types.Things (Thing)

import Data.Map (Map)

type Runner = Map String Thing -> Fallible Thing

data Definition = Definition {
	location :: Location,  -- Forward declarations may make this different from declaration's.
	declaration :: Declaration,
	runWith :: Runner }