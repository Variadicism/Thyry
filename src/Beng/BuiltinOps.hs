{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

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
	define,
	defineUsing,
	declare
) where

import Prelude hiding ((<), (>))

import Beng.Ops (newLiteralOp, runOp)
import Beng.Types.OpPatterns (OpPattern(..))
import Beng.Types.Ops (OpArg(..), OpDefinition(..), OpDeclaration(..), OpRunner, OpValue(..), OpValuePrimitiveType(..), PreOpContextsBuilder)

import Data.Map (Map, (!))
import qualified Data.Map as Map
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

(<.>) :: OpDeclaration -> OpPattern -> OpDeclaration  -- OpAnd
(<.>) previousDec@OpDeclaration{..} nextPattern =
	if OMap.null opArgsAndSuffixes then
		previousDec{ opPrefix = andPatterns opPrefix nextPattern }
	else do
		let Just (lastArg, suffix) = opArgsAndSuffixes `OMap.elemAt` (OMap.size opArgsAndSuffixes - 1)
		let newArgsAndSuffixes = opArgsAndSuffixes >| (lastArg, andPatterns suffix nextPattern)
		previousDec{ opArgsAndSuffixes = newArgsAndSuffixes }
infixl 5 <.>

(<*+>) :: (OpPattern -> String -> OpPattern)  -- OpDelimited
(<*+>) = flip OpDelimited
infixl 7 <*+>

(<) ::
	(OpDeclaration -> (String, OpValuePrimitiveType) -> (OpDeclaration, (String, OpValuePrimitiveType)))
(<) = (,)
infixl 5 <

(>) :: (OpDeclaration, (String, OpValuePrimitiveType)) -> OpPattern -> OpDeclaration
(>) (previousDefinition, (argName, argPrimType)) nextPattern = previousDefinition{
	opArgsAndSuffixes = opArgsAndSuffixes previousDefinition >|
		(OpArg { argName = argName, argPrimitiveType = argPrimType }, nextPattern) }
infixl 5 >

defineUsing :: OpDeclaration -> PreOpContextsBuilder -> OpRunner -> OpDefinition
defineUsing = OpDefinition

define :: OpDeclaration -> OpRunner -> OpDefinition
define declaration runner = defineUsing declaration (const Map.empty) runner

declare :: OpPattern -> OpDeclaration
declare prefix = OpDeclaration {
	opPrefix = prefix,
	opArgsAndSuffixes = OMap.empty }

-- These builtins are currently placeholders for testing the parsing and running capabilities.
builtinOps :: [OpDefinition]
builtinOps =
	-- Define 2 and 3 as basic operators.
	map (\v -> newLiteralOp (show v) (IntValue v)) [2, 3] ++ [
		-- Augend + Addend
		define
			(declare e < ("Augend", IntValueType) > s <.> l "+" <.> s < ("Addend", IntValueType) > e)
			\args -> do
				-- It's so annoying that the types of the arguments and the values in here are disjointed,
				-- losing all type guarantees. This will not be an issue in Beng!
				let (IntValue augend) = args ! "Augend"
				let (IntValue addend) = args ! "Addend"
				IntValue $ augend + addend,
		-- Minuend - Subtrahend
		define
			(declare e < ("Minuend", IntValueType) > s <.> l "-" <.> s < ("Subtrahend", IntValueType) > e)
			\args -> do
				let (IntValue minuend) = args ! "Minuend"
				let (IntValue subtrahend) = args ! "Subtrahend"
				IntValue $ minuend - subtrahend,
		-- a := Value SCOPE
		-- TODO: Scope should be a list of preops, but lists will come later.
		defineUsing
			(declare (l "a") <.> s <.> l ":=" <.> s < ("Value", IntValueType) >
				s < ("Scope", PreOpValueType) > e)
			(\args -> Map.singleton "Scope" [
				define (declare $ l "a") $ const $ args ! "Value"])
			\args -> do
				let (OpOpValue scope) = args ! "Scope"
				runOp scope ]
