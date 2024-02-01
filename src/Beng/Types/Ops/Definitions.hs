module Beng.Types.Ops.Definitions (
	Definition(..),
	Runner
) where

import Beng.Parse.Matches (Capture)
import Beng.Run.Types.Data (Data)
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (Location)
import Beng.Types.Ops.Declarations (Declaration)

import Data.Map (Map)

type Runner = Map String Capture -> Fallible Data

data Definition = Definition {
	location :: Location,  -- Forward declarations may make this different from declaration's.
	declaration :: Declaration,
	runWith :: Runner }