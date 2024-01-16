module Beng.Parse.Patterns.Arg (
	parse
) where

import Utils.Lists (wrap)

import {-# SOURCE #-} qualified Beng.Build.Ops as Op
import Beng.Parse.Matches (Match(..))
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>/\>), Parser, PrefixState(..), State(..), takeAs, takeNone)
import Beng.Run.Values (ValueType)

import qualified Data.Map as Map

-- exported

parse :: String -> ValueType -> Parser Match
-- TODO: use valueType to figure out if it should be parsed as an Op, PreOp, or normal Value.
parse name valueType = "argument " ++ wrap "'" name @> \state ->
	case state.prefixState of
		AvoidingFor op -> takeAs "" (Argument { name, op }) state{ prefixState = Unneeded }
		Needed -> takeNone state
		Unneeded -> state >>>
			Op.build (wrap "'" name ++ " :: " ++ show valueType) >/\>
			(\s op -> s{ arguments = Map.insert name op s.arguments }) >\>
			\op -> Argument { name, op }