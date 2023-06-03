{-# LANGUAGE OverloadedStrings #-}

module Beng.BuiltinOps (
	builtinOps,
	e,
	s,
	l,
	andPatterns,
	(<.>),
	(<*+>),
	(<),
	(>),
	(<>=>),
	define
) where

import Prelude hiding ((<), (>))

import Beng.Ops (newLiteralOp)
import Beng.Types.OpPatterns (OpPattern(..))
import Beng.Types.Ops (OpArg(..), OpDefinition(..), OpValue(..))

import Data.Map (Map, (!))
import Data.Map.Ordered ((>|))
import qualified Data.Map.Ordered as OMap (empty, fromList, lookup, elemAt, null, size)
import Data.Text.Lazy (Text, pack)

-- private utils

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

(<>=>) :: OpDefinition -> (Map String OpValue -> OpValue) -> OpDefinition
(<>=>) definition runner = definition{ runOpWith = runner }
infixl 1 <>=>

define :: OpPattern -> OpDefinition
define prefix = OpDefinition { opPrefix = prefix,
	argsAndSuffixes = OMap.empty,
	runOpWith = error "This op definition has no runner!" }

-- These builtins are currently placeholders for testing the parsing and running capabilities.
builtinOps :: [OpDefinition]
builtinOps =
	-- Define 2 and 3 as basic operators.
	map (\v -> newLiteralOp (show v) (IntValue v)) [2, 3] ++ [
		-- Augend + Addend
		define e < "Augend" > s <.> l "+" <.> s < "Addend" > e <>=> \args -> do
			-- It's so annoying that the types of the arguments and the values in here are disjointed,
			-- losing all type guarantees. This will not be an issue in Beng!
			let (IntValue augend) = args ! "Augend"
			let (IntValue addend) = args ! "Addend"
			IntValue $ augend + addend,
		-- Minuend - Subtrahend
		define e < "Minuend" > s <.> l "-" <.> s < "Subtrahend" > e <>=> \args -> do
			let (IntValue minuend) = args ! "Minuend"
			let (IntValue subtrahend) = args ! "Subtrahend"
			IntValue $ minuend - subtrahend ]
