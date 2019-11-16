{-# LANGUAGE OverloadedStrings #-}

module Beng.StandardOps (
	standardOps,
	e,
	s,
	l,
	andPatterns,
	(<.>),
	(<*+>),
	(<),
	(>),
	(<>=>),
	define,
) where

import Prelude hiding ((<), (>))

import Beng.Read.Ops
import Beng.Read.OpPatterns
import Beng.Values

import Data.Map (Map, (!))
import Data.Map.Ordered ((>|))
import qualified Data.Map.Ordered as OMap (empty, fromList, lookup, elemAt, null, size)
import Data.Text.Lazy (Text, pack)

e :: OpPattern
e = OpEmpty

s :: OpPattern
s = OpSpace

l :: (Text -> OpPattern)
l = OpLiteral

andPatterns :: OpPattern -> OpPattern -> OpPattern
andPatterns OpEmpty nextPattern = nextPattern
andPatterns (OpAnd previousPatternParts) nextPattern = OpAnd $ previousPatternParts ++ [nextPattern]
andPatterns previousPattern nextPattern = OpAnd [previousPattern, nextPattern]

(<.>) :: OpDefinition -> OpPattern -> OpDefinition  -- OpAnd
(<.>) previousDef nextPattern = do
	let previousArgsAndSuffixes = argsAndSuffixes previousDef
	if OMap.null previousArgsAndSuffixes then
		previousDef{ opPrefix = andPatterns (opPrefix previousDef) nextPattern }
	else do
		let Just (lastArg, suffix) = previousArgsAndSuffixes `OMap.elemAt` (OMap.size previousArgsAndSuffixes - 1)
		let newArgsAndSuffixes = previousArgsAndSuffixes >| (lastArg, andPatterns suffix nextPattern)
		previousDef{ argsAndSuffixes = newArgsAndSuffixes }
infixl 5 <.>

(<*+>) :: (OpPattern -> String -> OpPattern)  -- OpDelimited
(<*+>) = flip OpDelimited
infixl 7 <*+>

(<) :: (OpDefinition -> String -> (OpDefinition, String))
(<) = (,)
infixl 5 <

(>) :: (OpDefinition, String) -> OpPattern -> OpDefinition
(>) (previousDefinition, argName) nextPattern = previousDefinition{
	argsAndSuffixes = argsAndSuffixes previousDefinition >| (OpArg { argName = argName }, nextPattern) }
infixl 5 >

(<>=>) :: OpDefinition -> (Map String Value -> Value) -> OpDefinition
(<>=>) definition runner = definition{ runOpWith = runner }
infixl 1 <>=>

define :: OpPattern -> OpDefinition
define prefix = OpDefinition { opPrefix = prefix,
	argsAndSuffixes = OMap.empty,
	runOpWith = error "This op definition has no runner!" }

standardOps :: [OpDefinition]
-- standardOps = map (\v -> newLiteralOp (show v) v) [2, 3] ++ [
--	-- Augend + Addend
--	OpDefinition { opPrefix = e, argsAndSuffixes = OMap.fromList [
--			(OpArg { argName = "Augend" }, OpAnd [OpSpace, OpLiteral "+", OpSpace]),
--			(OpArg { argName = "Addend" }, OpEmpty)],
--		runOpWith = \args -> args ! "Augend" + args ! "Addend" },
--	-- Minuend - Subtrahend
--	OpDefinition { opPrefix = OpEmpty, argsAndSuffixes = OMap.fromList [
--			(OpArg { argName = "Minuend" }, OpAnd [OpSpace, OpLiteral "-", OpSpace]),
--			(OpArg { argName = "Subtrahend" }, OpEmpty)],
--		runOpWith = \args -> args ! "Minuend" - args ! "Subtrahend" }]
standardOps = map (\v -> newLiteralOp (show v) v) [2, 3] ++ [
		define e < "Augend" > s <.> l "+" <.> s < "Addend" > e <>=>
			\args -> args ! "Augend" + args ! "Addend",
		define e < "Minuend" > s <.> l "-" <.> s < "Subtrahend" > e <>=>
			\args -> args ! "Minuend" - args ! "Subtrahend" ]
