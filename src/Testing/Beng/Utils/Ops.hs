module Testing.Beng.Utils.Ops (
	assertOp,
	run,
	runInt
) where

import Utils.Errors
import Utils.Messaging (debugM)
import Utils.Testing
import Utils.Tuples (map2)

import Beng.Ops (Op(..), getArgs)
import Beng.Types.Ops.Definitions (Definition, runWith)
import Beng.Run.Types.Values (Value(IntValue))

import Data.List (sort)
import Data.Map ((!?))
import qualified Data.Map as Map

assertOp :: Definition -> [(String, Op -> Fallible ())] -> Op -> Fallible ()
assertOp definition argAssertions op = do
	debugM $ "Asserting correct structure of " ++ show op ++ "..."
	(op.definition, definition) `isEqualElse` "The definition was not the one expected!"

	let args = getArgs op
	let assertArg name assertion = case args !? name of
		Nothing -> toError $ "The argument '" ++ name ++ "' was expected, but not found!"
		Just argOp -> assertion argOp
	reduceErrors $ map (uncurry assertArg) argAssertions

	-- If |args| < |argAssertions|, there would be an error above.
	map2 sort (Map.keys args, map fst argAssertions) `isEqualElse` "There are extra arguments!"

run :: Op -> Value
run op = op.definition.runWith Map.empty

runInt :: Op -> Int
runInt op = int where (IntValue int) = run op