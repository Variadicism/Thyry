module Beng.Run.Types.Values (
	Value(..)
) where

import Beng.Run.Types.Data (Data)

import Data.Text.Lazy (Text)

data Value =
	DataValue { value :: Data } |
	StringValue { text :: Text } |
	ListValue { values :: [Value] } |
	MaybeValue { maybeValue :: Maybe Value }