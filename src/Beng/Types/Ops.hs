module Beng.Types.Ops (
	Op(..)
) where

import Beng.Types.Build.Cards (Card)
import Beng.Types.Parse.Matches (Match)
import Beng.Types.Locations (Location)

data Op = Op {
	card :: Card,
	location :: Location,
	match :: Match }