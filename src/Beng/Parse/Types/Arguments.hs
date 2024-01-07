module Beng.Parse.Types.Arguments (
	Definition(..),
	Match(..)
) where

import {-# SOURCE #-} Beng.Types.Ops (Op)
import Beng.Run.Types.Values (ValueType)

data Definition = Definition {
	name :: String,
	valueType :: ValueType }

data Match = Match {
	definition :: Definition,
	op :: Op }