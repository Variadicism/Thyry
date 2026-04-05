module Testing.Beng.Utils.Ops (
	argAssertionsOf
) where

import Utils.Fallible
import Utils.Lists (wrap)
import Utils.Messaging (debugM)
import Utils.Testing
import Utils.Tuples (map2)

import qualified Beng.Operators as Ops
import Beng.Invocations (getArgs)
import Beng.Operators.Declarations (Declaration(..))
import Beng.Types.Operators.Definitions (Definition(..))
import Beng.Types.Invocations (Invocation(..), SomeInvocation(..))
import Beng.Types.Parse.Matches (value)
import Beng.Things (SomeThing)
import Beng.Types.Things (castThing)

import Data.List (sort)
import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap

import GHC.Records (HasField(..))

-- instances

instance HasField "op" (SomeInvocation -> Fallible a) (SomeThing -> Fallible a) where
	getField assertion value = case castThing value of
		Just op -> assertion op
		Nothing -> Error $
			"A single InvValue was expected, but I found a(n) " ++ show value ++ "!"

instance HasField "op" (i -> SomeInvocation -> Fallible a) (i -> SomeThing -> Fallible a) where
	getField assertion = \i -> (assertion i).op

instance HasField "op" (i -> j -> SomeInvocation -> Fallible a) (i -> j -> SomeThing -> Fallible a) where
	getField assertion = \i j -> (assertion i j).op

instance HasField "args" Definition ([(String, SomeThing -> Fallible ())] -> SomeInvocation -> Fallible ()) where
	getField = argAssertionsOf

instance HasField "null" Definition (SomeInvocation -> Fallible ()) where
	getField definition = definition.args []

argAssertionsOf :: Definition -> [(String, SomeThing -> Fallible ())] -> SomeInvocation -> Fallible ()
argAssertionsOf definition argAssertions invocation =
	prependToError ("In op " ++ wrap "`" (show invocation) ++ ", ") do
		debugM $ "Asserting correct structure of " ++ show invocation ++ "..."
		case invocation of
			SomeInvocation typedInvocation -> do
				(definition.declaration, declarationOf typedInvocation) `isEqualElse`
					"The definition was not the one expected!"

				let args = getArgs invocation
				let assertArg name assertion = case OMap.lookup name args of
					Nothing -> Error $ "The argument '" ++ name ++ "' was expected, but not found!"
					Just argOp -> assertion argOp
				sequence $ map (\(name, assertVal) -> assertArg name $ assertVal . value) argAssertions

				map2 sort (map fst argAssertions, Map.keys $ OMap.toMap args) `isEqualElse`
					-- If |args| < |argAssertions|, there would be an error above.
					"There are extra arguments!"
	where
		declarationOf :: Ops.Operator op => Invocation op -> Declaration
		declarationOf Invocation{operator = op} = Declaration {
			location = Ops.decLoc op,
			pattern = Ops.pattern op,
			returnType = Ops.returnType op,
			associativity = Ops.associativity op,
			precedence = Ops.precedence op,
			contextualize = Ops.contextualize op }
