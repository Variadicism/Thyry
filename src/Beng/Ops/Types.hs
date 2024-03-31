module Beng.Ops.Types (
	Op(..)
) where

import Beng.Build.Types.Cards (Card)
import Beng.Parse.Types.Matches (Match)
import Beng.Types.Locations (Location)

data Op = Op {
	card :: Card,
	location :: Location,
	match :: Match }