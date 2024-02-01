module Beng.Run.Types.Values (
	Value(..)
) where

import Utils.Populace (Populace)

import Beng.Run.Types.Data (Data)

import Data.Text.Lazy (Text)

data Value =
	DataValue { value :: Data } |
	StringValue { text :: Text } |
	ListValue { values :: Populace Value } |
	MaybeValue { maybeValue :: Maybe Value }