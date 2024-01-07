module Beng.Types.Ops (
	PreOp(..),
	Op(..)
) where

import Beng.Parse.Types.Matches (Match)
import Beng.Types.Definitions (Definition)

import Data.Text.Lazy (Text)

data PreOp = PreOp {
	name :: String,
	content :: Text }

data Op = Op {
	definition :: Definition,
	match :: Match }