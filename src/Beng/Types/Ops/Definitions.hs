module Beng.Types.Ops.Definitions (
	Definition(..),
	Runner
) where

import Utils.Fallible

import Beng.Parse.Matches (Capture)
import Beng.Run.Types.Data (Data)
import Beng.Types.Ops.Declarations (Declaration)

import Data.Map (Map)

type Runner = Map String Capture -> Fallible Data

data Definition = Definition {
	declaration :: Declaration,
	runWith :: Runner }