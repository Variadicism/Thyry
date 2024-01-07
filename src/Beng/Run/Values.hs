module Beng.Run.Values (
	Value(..),
	ValueType(..)
) where

import Utils.Lists (showWithAnd)

import Beng.Ops ()
import Beng.Run.Types.Values (Value(..), ValueType(..))

-- instances

instance Show Value where
	show (PreOpValue preop) = show preop
	show (OpValue op) = show op
	show (ListValue values) = showWithAnd values
	show (MaybeValue maybeValue) = show maybeValue
	show (IntValue int) = show int

instance Show ValueType where
	show = \case
		PreOpType -> "preop"
		OpType -> "op"
		ListType{element} -> "[" ++ show element ++ "]"
		MaybeType{inner} -> show inner ++ "?"
		IntType -> "integer"