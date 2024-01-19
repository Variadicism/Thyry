module Beng.Run.Values (
	Value(..)
) where

import Utils.Lists (showWithAnd)

import Beng.Ops ()
import Beng.Run.Types.Values (Value(..))

-- instances

instance Show Value where
	show (DataValue dataOut) = show dataOut
	show (ListValue values) = showWithAnd values
	show (MaybeValue maybeValue) = show maybeValue