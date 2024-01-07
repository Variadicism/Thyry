module Beng.Build.Ops (
	buildNonPrefixed,
	buildPrefixed,
	build,
) where

import Beng.Build.Types.Context (Context(..))
import Beng.Ops.Definitions (canHavePrefix, mustHavePrefix)
import Beng.Parse.Parsers ((<<<), (@>), (@+>), (>|>), (>^\>), (>-\>), (>\>), Parser, State(..))
import qualified Beng.Parse.Patterns as Pattern
import qualified Beng.Parse.Types.Matches.NonPrefixed as NP
import Beng.Types.Ops (Op(..))
import Beng.Types.Ops.Declarations (Declaration(..))
import Beng.Types.Ops.Definitions (Definition(..))

buildNonPrefixed :: Op -> Parser Op
buildNonPrefixed previousOp = "non-prefixed op" @> \state -> do
	let parserForDef :: Definition -> Parser Op = \definition ->
		show definition @+>
		Pattern.parseNonPrefixed definition.declaration.pattern previousOp >-\> (\npMatch ->
		if npMatch.argCaptured
			then Just npMatch.match
			else Nothing) >\>
		\match -> Op { definition, match }
	let parser :: Parser Op =
		foldl1 (>|>) $
		map parserForDef $
		filter (not . mustHavePrefix) state.context.definitions
	-- TODO: precedence
	parser <<< state

buildPrefixed :: Parser Op
buildPrefixed = "prefixed op" @> \state -> do
	-- Context should at least include builtin ops, so there should always be definitions for `foldl1`.
	let parserForDef :: Definition -> Parser Op = \definition ->
		show definition @+>
		Pattern.parse definition.declaration.pattern >\>
		\match -> Op { definition, match }
	let parser :: Parser Op =
		foldl1 (>|>) $
		map parserForDef $
		filter canHavePrefix state.context.definitions
	parser <<< state

build :: String -> Parser Op
build contextDescription =
	contextDescription @+>
	buildPrefixed >^\>
	\argOp -> buildNonPrefixed argOp