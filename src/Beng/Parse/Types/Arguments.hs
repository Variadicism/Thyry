module Beng.Parse.Types.Arguments (
	Definition(..)
) where

import Beng.Run.Types.Values (ValueType)

data Definition = Definition {
	name :: String,
	valueType :: ValueType }