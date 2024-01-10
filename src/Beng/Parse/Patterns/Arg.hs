module Beng.Parse.Patterns.Arg (
	parse,
	parseNonPrefixed
) where

import Utils.Lists (wrap)

import {-# SOURCE #-} qualified Beng.Build.Ops as Op
import Beng.Parse.Matches (Match(..))
import qualified Beng.Parse.Matches.NonPrefixed as NonPrefixed
import Beng.Parse.Parsers ((@>), (>\>), Parser, takeAs)
import Beng.Run.Values (ValueType)
import Beng.Types.Ops (Op)

-- exported

parse :: String -> ValueType -> Parser Match
-- TODO: use valueType to figure out if it should be parsed as an Op, PreOp, or normal Value.
parse name valueType = Op.build (wrap "'" name ++ " :: " ++ show valueType) >\> 
	\op -> Argument { name, op }

parseNonPrefixed :: String -> ValueType -> Op -> Parser NonPrefixed.Match
-- TODO: use valueType to figure out if it should be parsed as an Op, PreOp, or normal Value.
parseNonPrefixed name _ op = "capture first argument" @>
	takeAs "" NonPrefixed.Match {
		argCaptured = True,
		match = Argument { name, op }}