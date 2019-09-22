{-# LANGUAGE OverloadedStrings #-}

module Beng.StandardOps (
	standardOps
) where

import Beng.Read.Ops
import Beng.Read.OpPatterns

import Data.Map ((!))
import qualified Data.Map.Ordered as OMap (fromList)

standardOps :: [OpDefinition]
standardOps = map (\v -> newLiteralOp (show v) v) [2, 3] ++ [
	-- Augend + Addend
	OpDefinition { opPrefix = OpEmpty, argsAndSuffixes = OMap.fromList [
			(OpArg { argName = "Augend" }, OpAnd [OpSpace, OpLiteral "+", OpSpace]),
			(OpArg { argName = "Addend" }, OpEmpty)],
		runOpWith = \args -> args ! "Augend" + args ! "Addend" },
	-- Minuend - Subtrahend
	OpDefinition { opPrefix = OpEmpty, argsAndSuffixes = OMap.fromList [
			(OpArg { argName = "Minuend" }, OpAnd [OpSpace, OpLiteral "-", OpSpace]),
			(OpArg { argName = "Subtrahend" }, OpEmpty)],
		runOpWith = \args -> args ! "Minuend" - args ! "Subtrahend" }]
