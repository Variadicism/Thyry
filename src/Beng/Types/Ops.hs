module Beng.Types.Ops (
	PreOp(..),
	Op(..)
) where

import Beng.Build.Types.Cards (Card)
import Beng.Parse.Types.Matches (Match)

import Data.Text.Lazy (Text)

data PreOp = PreOp {
	name :: String,
	content :: Text }

data Op = Op {
	card :: Card,
	match :: Match }