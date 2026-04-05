module Beng.Types.Operators.Definitions (
	Definition(..),
	Runner
) where

import Beng.Types.Operators.Declarations (Declaration)
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (Location)
import Beng.Types.Things (SomeThing)

import Data.Map (Map)

type Runner = Map String SomeThing -> Fallible SomeThing

data Definition = Definition {
	location :: Location,  -- Forward declarations may make this different from declaration's.
	declaration :: Declaration,
	runWith :: Runner }
