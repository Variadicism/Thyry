module Beng.Run.Types.Values (
	Data,
	ValueType(..),
	Value(..)
) where

import {-# SOURCE #-} Beng.Types.Ops (Op)

-- TODO: allow for data of different memory sizes
-- TODO: When we add compilation, this will become a data type that differentiates compile-time and runtime data.
type Data = Int

data ValueType =
	PreOpType |
	OpType |
	ListType { element :: ValueType } |
	MaybeType { inner :: ValueType } |
	DataType

data Value =
	{- A PreOp cannot be a value because without full context, Beng cannot parse a preop.
	   Instead, a context built with the ArgsContextBuilder will be used to parse it into an op. -}
	OpValue { op :: Op } |
	ListValue { values :: [Value] } |
	MaybeValue { maybeValue :: Maybe Value } |
	DataValue { dataValue :: Data }