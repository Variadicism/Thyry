module Beng.Run.Values (
	Data,
	Value(..),
	ValueType(..)
) where

import Utils.Lists (showWithAnd)

import Beng.Ops ()
import Beng.Run.Types.Values (Data, Value(..), ValueType(..))

-- instances

instance Show Value where
	show (OpValue op) = show op
	show (ListValue values) = showWithAnd values
	show (MaybeValue maybeValue) = show maybeValue
	show (DataValue int) = show int

instance Show ValueType where
	show = \case
		PreOpType -> "preop"
		OpType -> "op"
		ListType{element} -> "[" ++ show element ++ "]"
		MaybeType{inner} -> show inner ++ "?"
		DataType -> "data"

deriving instance Eq ValueType