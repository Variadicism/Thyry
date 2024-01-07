module Beng.Types.Ops.Definitions (
	ArgContextsBuilder,
	Definition(..),
	Runner
) where

import Beng.Parse.Types.Context (Context)
import Beng.Run.Types.Values (Value)
import Beng.Types.Ops.Declarations (Declaration)

import Data.Map (Map)

type ArgContextsBuilder = Map String Value -> Context -> Map String Context

type Runner = Map String Value -> Value

-- TODO: when ops can be defined dynamically, only the op declaration will apply; buildContexts and runOpWith are only to be defined for builtin ops because ops defined in code just run their body for both.
data Definition = Definition {
	declaration :: Declaration,
	buildContexts :: ArgContextsBuilder,
	runWith :: Runner }