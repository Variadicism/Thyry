module Beng.Parse.Patterns.Arg (
	parse,
	parseNonPrefixed
) where

import Beng.Types.Ops (Op)
import {-# SOURCE #-} qualified Beng.Parse.Ops as Op
import Beng.Parse.Matches (Match(..))
import qualified Beng.Parse.Matches.NonPrefixed as NonPrefixed
import Beng.Parse.Parsers ((@>), (>\>), Parser, takeAs)
import qualified Beng.Parse.Arguments as Arg

-- exported

parse :: Arg.Definition -> Parser Match
parse definition = Op.parse (show definition) >\> 
	\op -> Argument $ Arg.Match { definition, op }

parseNonPrefixed :: Arg.Definition -> Op -> Parser NonPrefixed.Match
parseNonPrefixed definition op = "capture first argument" @>
	takeAs "" NonPrefixed.Match {
		argCaptured = True,
		match = Argument $ Arg.Match { definition, op } }