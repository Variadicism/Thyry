module Testing.Beng.Utils.Ops (
	assertOp,
	assertArgEq,
	assertArgsEq,
	run,
	runInt
) where

import Utils.Errors
import Utils.Lists (wrap)
import Utils.Messaging (debugM)
import Utils.Testing
import Utils.Tuples (map2)

import Beng.Ops (Op(..), getArgs)
import Beng.Types.Ops.Definitions (Definition(..))
import Beng.Run.Ops (run)
import Beng.Run.Types.Values (Value(IntValue))

import Data.List (sort)
import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap

assertOp :: Definition -> [(String, Op -> Fallible ())] -> Op -> Fallible ()
assertOp definition argAssertions op =
	prependToError ("In op " ++ wrap "`" (show op) ++ ",...\n") do
		debugM $ "Asserting correct structure of " ++ show op ++ "..."
		(definition.declaration, op.card.declaration) `isEqualElse` "The definition was not the one expected!"

		let args = getArgs op
		let assertArg name assertion = case OMap.lookup name args of
			Nothing -> toError $ "The argument '" ++ name ++ "' was expected, but not found!"
			Just argOp -> assertion argOp
		reduceErrors $ map (uncurry assertArg) argAssertions

		map2 sort (map fst argAssertions, Map.keys $ OMap.toMap args) `isEqualElse`
			-- If |args| < |argAssertions|, there would be an error above.
			"There are extra arguments!"

assertArgEq :: String -> Definition -> Op -> Fallible ()
assertArgEq name definition argOp =
	(definition.declaration, argOp.card.declaration) `isEqualElse`
		(wrap "'" name ++ " didn't have the definition expected!")

assertArgsEq :: Definition -> [(String, Definition)] -> (Op -> Fallible ())
assertArgsEq definition argDefinitions =
	assertOp definition $ map assertOpArgDef argDefinitions
	where
		assertOpArgDef :: (String, Definition) -> (String, Op -> Fallible ())
		assertOpArgDef (name, def) = (name, assertArgEq name def)

runInt :: Op -> Fallible Int
runInt op = do
	IntValue int <- run op
	return int 