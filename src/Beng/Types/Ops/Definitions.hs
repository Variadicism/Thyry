module Beng.Types.Ops.Definitions (
	Definition(..),
	Runner
) where

import Utils.Errors

import Beng.Run.Types.Values (Value)
import Beng.Types.Ops.Declarations (Declaration)

import Data.Map (Map)

type Runner = Map String Value -> Fallible Value

data Definition = Definition {
	declaration :: Declaration,
	runWith :: Runner }