module Beng.Parse.Patterns.Arg (
	parse
) where

import Utils.Fallible
import Utils.Messaging (debugM, msg)
import Utils.Lists (wrap)
import Utils.Strings (pluralCount)

import Beng.Build.Cards ()
import Beng.Build.Context (pushCard)
import {-# SOURCE #-} qualified Beng.Build.Ops as Op
import Beng.Errors (parseError)
import Beng.Parse.Matches (Match(Argument, decLoc, name, argType, argValue), Parameter(..))
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>/\>), Parser, PrefixState(..), State(..), takeAs)
import Beng.Types.Locations (Location)
import qualified Beng.Types.Locations as Location
import Beng.Ops.Types.Declarations (Declaration(..))
import Beng.Values.Types (Type, Value(OpValue))

import Control.Monad (when)
import qualified Data.Map as Map

-- exported

parse :: String -> Type -> Location -> Parser Match
parse name argType decLoc = wrap "'" name ++ ", " ++ msg argType @> \state -> do
	let argOf op = Argument { decLoc, name, argType, argValue = OpValue op }
	let putArg op state = do
		let newArg = Parameter { name, decLoc, paramType = argType, value = OpValue op }
		state { arguments = Map.insert name newArg state.arguments }
	case state.prefixState of
		AvoidingFor op ->
			takeAs "" (argOf op) $ putArg op $ state{ prefixState = Unneeded }
		Needed -> Error $ parseError state $
			"An op prefix was needed, but " ++ show state.parent ++ " had none!"
		Unneeded -> do
			-- Arg Patterns are only applicable within ops, so parent must be present.
			let (Just parent) = state.parent
			prependToError ("in '" ++ name ++ "' of " ++ msg parent ++ ", ") do
				-- TODO: add previous arguments as additional context
				argContext <- prependToError
						("There was an error attempting to build a context to parse the preop for " ++
							wrap "'" name ++ ": ") $
					parent.declaration.contextualize name state.arguments (Location.Code state.location)
				when (not $ null argContext) $ debugM $
					pluralCount (length argContext) "contextual card" ++ " generated for '" ++
					name ++ "': " ++ show argContext
				let newContext = foldl (flip pushCard) state.context argContext
				state{ context = newContext } >>>
					(Op.build (wrap "'" name) >/\>
						\s op -> putArg op s{ context = state.context }) >\>
					\op -> Argument { decLoc, name, argType, argValue = OpValue op }