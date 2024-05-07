module Testing.Beng.Utils.Ops (
	argAssertionsOf
) where

import Utils.Fallible
import Utils.Lists (wrap)
import Utils.Messaging (debugM)
import Utils.Testing
import Utils.Tuples (map2)

import Beng.Ops (Op(..), getArgs)
import Beng.Types.Ops.Definitions (Definition(..))
import Beng.Types.Parse.Matches (value)
import Beng.Types.Values (Value(OpValue))

import Data.List (sort)
import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap

import GHC.Records (HasField(..))

-- instances

instance HasField "op" (Op -> Fallible a) (Value -> Fallible a) where
	getField assertion = \case
		OpValue op -> assertion op
		capture -> Error $ "A single OpValue was expected, but I found a(n) " ++ show capture ++ "!"

instance HasField "op" (i -> Op -> Fallible a) (i -> Value -> Fallible a) where
	getField assertion = \i -> (assertion i).op

instance HasField "op" (i -> j -> Op -> Fallible a) (i -> j -> Value -> Fallible a) where
	getField assertion = \i j -> (assertion i j).op

instance HasField "args" Definition ([(String, Value -> Fallible ())] -> Op -> Fallible ()) where
	getField = argAssertionsOf

instance HasField "null" Definition (Op -> Fallible ()) where
	getField definition = definition.args []

argAssertionsOf :: Definition -> [(String, Value -> Fallible ())] -> Op -> Fallible ()
argAssertionsOf definition argAssertions op =
	prependToError ("In op " ++ wrap "`" (show op) ++ ", ") do
		debugM $ "Asserting correct structure of " ++ show op ++ "..."
		(definition.declaration, op.card.declaration) `isEqualElse`
			"The definition was not the one expected!"

		let args = getArgs op
		let assertArg name assertion = case OMap.lookup name args of
			Nothing -> Error $ "The argument '" ++ name ++ "' was expected, but not found!"
			Just argOp -> assertion argOp
		sequence $ map (\(name, assertVal) -> assertArg name $ assertVal . value) argAssertions

		map2 sort (map fst argAssertions, Map.keys $ OMap.toMap args) `isEqualElse`
			-- If |args| < |argAssertions|, there would be an error above.
			"There are extra arguments!"
