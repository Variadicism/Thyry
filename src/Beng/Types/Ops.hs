module Beng.Types.Ops (
	Op(..)
) where

import Beng.Build.Types.Cards (Card)
import Beng.Parse.Types.Matches (Match)

data Op = Op {
	card :: Card,
	match :: Match }