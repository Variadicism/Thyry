module Beng.Parse.Patterns.Arg (
	parse
) where

import Utils.Lists (wrap)

import {-# SOURCE #-} qualified Beng.Build.Ops as Op
import Beng.Parse.Matches (Match(..))
import Beng.Parse.Parsers ((@>), (<<<), (>\>), Parser, PrefixState(..), State(prefixState), takeAs, takeNone)
import Beng.Run.Values (ValueType)

-- exported

parse :: String -> ValueType -> Parser Match
-- TODO: use valueType to figure out if it should be parsed as an Op, PreOp, or normal Value.
parse name valueType = "argument " ++ wrap "'" name @> \state ->
	case state.prefixState of
		AvoidingFor op -> takeAs "" (Argument { name, op }) state{ prefixState = Unneeded }
		Needed -> takeNone state
		Unneeded -> (
			Op.build (wrap "'" name ++ " :: " ++ show valueType) >\>
			\op -> Argument { name, op })
			<<< state