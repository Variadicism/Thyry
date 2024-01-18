module Beng.Parse.Patterns.Arg (
	parse
) where

import Utils.Lists (wrap)
import Utils.Tuples (mapFst2)

import {-# SOURCE #-} qualified Beng.Build.Ops as Op
import Beng.Build.Types.Cards (Card)
import Beng.Build.Context (Context, pushCard)
import Beng.Parse.Matches (Capture(..), Match(..))
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>/>), (>/\>), Parser, PrefixState(..), State(..), takeAs, takeNone)
import Beng.Run.Values (ValueType(..))
import Beng.Types.Ops (Op)
import Beng.Types.Ops.Declarations (Declaration(..))

import Data.Map ((!?))
import qualified Data.Map as Map

-- private

buildOpWith :: String -> Context -> Parser Op
buildOpWith name context = "build op contextualized under " ++ wrap "'" name @> \state ->
	state{ context } >>>
		Op.build (wrap "'" name) >/>
		\s -> s{ context = state.context }

buildAs :: String -> ValueType -> Parser (Capture, Op)
buildAs name valueType = "build " ++ wrap "'" name ++ " as " ++ show valueType @> \state -> do
	-- Arg Patterns are only parsed for ops, so parent must be present.
	let (Just parent) = state.parent
	let declaration = parent.declaration
	case valueType of
		OpType -> state >>>
			buildOpWith name state.context >\>
			\op -> (OpCapture op, op)
		PreOpType -> do
			let argContexts = case declaration.buildContexts state.arguments of
				-- TODO: when the Parser results can include errors, carry this error back correctly.
				Left errorMessage -> error $
					"There was an error attempting to build a context to parse the preop for " ++
					wrap "'" name ++ ": " ++ errorMessage
				Right argContexts -> argContexts
			let appendToContext :: [Card] -> Context =
				foldl (flip pushCard) state.context
			let argContext = maybe state.context appendToContext $ argContexts !? name
			state >>>
				buildOpWith name argContext >\>
				\op -> (OpCapture op, op)
		DataType -> state >>>
			buildOpWith name state.context >\>
			\op -> (OpCapture op, op)
		ListType{element} -> state >>>
			buildAs name element >\> \(newCaptureElement, newOp) -> do
				let newListCapture = case state.arguments !? name of
					Nothing -> ListCapture { captures = [newCaptureElement] }
					Just oldCapture -> do
						-- A ListType corresponds to a ListCapture.
						let ListCapture{captures=oldCaptures} = oldCapture
						ListCapture { captures = oldCaptures ++ [newCaptureElement] }
				(newListCapture, newOp)
		MaybeType{inner} -> state >>>
			buildAs name inner >\>
			mapFst2 (MaybeCapture . Just)

-- exported

parse :: String -> ValueType -> Parser Match
parse name valueType = "argument " ++ wrap "'" name @> \state ->
	case state.prefixState of
		AvoidingFor op -> do
			let match = Argument { name, valueType, op }
			takeAs "" match state{ prefixState = Unneeded }
		Needed -> takeNone state
		Unneeded -> state >>>
			buildAs name valueType >/\>
			(\s (capture, _) -> s{ arguments = Map.insert name capture s.arguments }) >\>
			\(_, op) -> Argument { name, valueType, op }
				