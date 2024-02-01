module Beng.Run.Values (
	Value(..)
) where

import Beng.Ops ()
import Beng.Run.Types.Values (Value(..))

-- instances

instance Show Value where
	show (DataValue dataOut) = show dataOut
	show (StringValue text) = show text
	show (ListValue values) = show values
	show (MaybeValue maybeValue) = show maybeValue