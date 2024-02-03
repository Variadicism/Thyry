module Beng.Parse.Patterns.Arg (
	parse
) where

import Utils.Fallible
import Utils.Messaging (debugM)
import Utils.Lists (wrap)
import qualified Utils.Populace as P
import Utils.Strings (pluralCount)
import Utils.Tuples (mapFst2)

import {-# SOURCE #-} qualified Beng.Build.Ops as Op
import Beng.Build.Context (Context, pushCard)
import Beng.Errors (parseError)
import Beng.Parse.Matches (Capture(..), Match(..))
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>/>), (>/\>), Parser, PrefixState(..), State(..), takeAs)
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Types.Patterns (ArgumentType(..))
import Beng.Types.Ops (Op)
import Beng.Types.Ops.Declarations (ArgContextBuilder, Declaration(..))

import Control.Monad (when)
import Data.Map ((!?))
import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap

-- private

buildOpWith :: String -> Context -> Parser Op
buildOpWith name context = "build op contextualized under " ++ wrap "'" name @> \state ->
	state{ context } >>>
		Op.build (wrap "'" name) >/>
		\s -> s{ context = state.context }

buildAs :: String -> ArgumentType -> ArgContextBuilder -> Parser (Capture, Op)
buildAs name captureType contextualize = "build " ++ wrap "'" name @> \state -> do
	case captureType of
		OpType -> do
			argContext <- prependToError
					("There was an error attempting to build a context to parse the preop for " ++
					wrap "'" name ++ ": ") $
				contextualize name state.arguments state.location
			when (not $ null argContext) $ debugM $
				pluralCount (length argContext) "contextual card" ++ " generated for '" ++
				name ++ "': " ++ show argContext
			let newContext = foldl (flip pushCard) state.context argContext
			state >>>
				buildOpWith name newContext >\>
				\op -> (OpCapture op, op)
		ListType{element} -> state >>>
			buildAs name element contextualize >\>
			\(newCaptureElement, newOp) -> do
				let newListCapture = case state.arguments !? name of
					Nothing -> ListCapture { captures = P.singleton newCaptureElement }
					Just oldCapture -> do
						-- Assume it's a ListCapture because it's for a ListType argument.
						let ListCapture{captures=oldCaptures} = oldCapture
						ListCapture { captures = oldCaptures <> P.singleton newCaptureElement }
				(newListCapture, newOp)
		MaybeType{inner} -> state >>>
			buildAs name inner contextualize >\>
			mapFst2 (MaybeCapture . Just)
		-- Yeah, this is stupid, but I'm struggling to find a better solution. :|
		StringType -> error $ "StringCaptures should be parsed by NamedText Patterns, not Args!"

-- exported

parse :: String -> Parser Match
parse name = "argument " ++ wrap "'" name @> \state ->
	case state.prefixState of
		AvoidingFor op -> do
			let match = Argument { name, op }
			takeAs "" match state{ prefixState = Unneeded }
		Needed -> Error $ parseError state $
			"An op prefix was needed, but " ++ show state.parent ++ " has none!"
		Unneeded -> do
			-- Arg Patterns are only applicable within ops, so parent must be present.
			let (Just parent) = state.parent
			let declaration = parent.declaration
			-- If the arg is being parsed in parent, parent must have declared it in the Pattern.
			let (Just captureType) = OMap.lookup name $ Pattern.getArgs declaration.pattern
			state >>>
				buildAs name captureType declaration.contextualize >/\>
				(\s (capture, _) -> s{ arguments = Map.insert name capture s.arguments }) >\>
				\(_, op) -> Argument { name, op }