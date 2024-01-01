module Beng.Ops (
	runOp,
	newLiteralOp,
) where

import Prelude hiding (lookup)

import Beng.Types.OpPatterns (OpPattern(..))
import Beng.Types.Ops (Op(..), OpValue, OpDeclaration(..), OpDefinition(..))

import qualified Data.Map as Map (empty, map)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (pack)

-- builtins

-- There is a subtly represented but CRUCIAL property of Beng noted here. Notice how running an op returns a value -- JUST a value. It is INFALLIBLE! This should ALWAYS HOLD TRUE! If this language compiles, it should be able to run without EVER throwing an error!! Errors will be handled inside the program and can print messages and close or whatever, but the program CANNOT CRASH!
runOp :: Op -> OpValue
runOp Op{opDefinition=OpDefinition{..},..} = runOpWith $ Map.map runOp argValues

-- utilities

newLiteralOp :: String -> OpValue -> OpDefinition
newLiteralOp literal value = OpDefinition {
	opDeclaration = OpDeclaration {
		opPrefix = OpLiteral $ pack literal,
		opArgsAndSuffixes = OMap.empty },
	buildPreOpContexts = const Map.empty,
	runOpWith = const value }
