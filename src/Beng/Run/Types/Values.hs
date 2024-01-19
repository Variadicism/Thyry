module Beng.Run.Types.Values (
	Value(..)
) where

import Beng.Run.Types.Data (Data)

data Value =
	DataValue { value :: Data } |
	ListValue { values :: [Value] } |
	MaybeValue { maybeValue :: Maybe Value }