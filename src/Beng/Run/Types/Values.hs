module Beng.Run.Types.Values (
	ValueType(..),
	Value(..)
) where

import {-# SOURCE #-} Beng.Types.Ops (Op, PreOp)

data ValueType =
	PreOpType |
	OpType |
	ListType { element :: ValueType } |
	MaybeType { inner :: ValueType } |
	IntType

data Value =
	PreOpValue { preOp :: PreOp } |
	OpValue { op :: Op } |
	ListValue { values :: [Value] } |
	MaybeValue { maybeValue :: Maybe Value } |
	IntValue { int :: Int }