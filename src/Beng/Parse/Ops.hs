module Beng.Parse.Ops (
	parseNonPrefixed,
	parsePrefixed,
	parse,
) where

import qualified Beng.Ops.Definitions as Def
import Beng.Parse.Parsers ((<<<), (@>), (@+>), (>|>), (>^\>), (>-\>), (>\>), Parser, State(..))
import qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Types.Context (Context(..))
import qualified Beng.Parse.Types.Matches.NonPrefixed as NP
import Beng.Types.Declarations (Declaration(..))
import Beng.Types.Definitions (Definition(..))
import Beng.Types.Ops (Op(..))

parseNonPrefixed :: Op -> Parser Op
parseNonPrefixed previousOp = "non-prefixed op" @> \state -> do
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
		filter (not . Def.mustHavePrefix) state.context.definitions
	-- TODO: precedence
	parser <<< state

parsePrefixed :: Parser Op
parsePrefixed = "prefixed op" @> \state -> do
	-- Context should at least include builtin ops, so there should always be definitions for `foldl1`.
	let parserForDef :: Definition -> Parser Op = \definition ->
		show definition @+>
		Pattern.parse definition.declaration.pattern >\>
		\match -> Op { definition, match }
	let parser :: Parser Op =
		foldl1 (>|>) $
		map parserForDef $
		filter Def.canHavePrefix state.context.definitions
	parser <<< state

parse :: String -> Parser Op
parse contextDescription =
	contextDescription @+>
	parsePrefixed >^\>
	\argOp -> parseNonPrefixed argOp