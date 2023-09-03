{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Prelude hiding ((<), (>))

import Utils.Errors
import Utils.Monads (void)
import Utils.Testing

import Beng.BuiltinOps (e, s, l, andPatterns, (<.>), (<*+>), (<), (>), declare, define)
import Beng.Read.Ops (readOp, readCode)
import Beng.Types.Ops (Op(..), OpDefinition(..), OpValue(..), OpValuePrimitiveType(..))

import Data.Map (Map, (!))
import qualified Data.Map as Map (empty, null)


aValue :: Int
aValue = 2

bValue :: Int
bValue = 4

mockContext :: [OpDefinition]
mockContext = [
	define (declare $ l "a") \args -> IntValue aValue,
	define (declare $ l "b") \args -> IntValue bValue,
	define
		(declare e < ("Dividend", IntValueType) > l "/" < ("Divisor", IntValueType) > e)
		\args -> do
			let (IntValue dividend) = args ! "Dividend"
			let (IntValue divisor) = args ! "Divisor"
			IntValue $ dividend `div` divisor ]

oneNullaryOpCode = "a"

oneNullaryThenInvalidCode = "a j"

invalidThenOneNullaryCode = "j a"

twoNullaryOpCode = "ab"

getRunValueRaw :: Op -> OpValue
getRunValueRaw op = (runOpWith $ opDefinition op) Map.empty

getRunValue :: Op -> Int
getRunValue op = int where (IntValue int) = getRunValueRaw op

main :: IO ()
main = do
	-- readOp
	-- Read one nullary op that covers the entire code.
	let aReadPossibilities = readOp mockContext oneNullaryOpCode
	(length aReadPossibilities, 1) `isEqualElse` "This mock code should have been parsed as one nullary op!"
	let (aRead, afterA) = head aReadPossibilities
	assert (Map.null $ argValues aRead) "The op parsed should have been nullary!"
	(getRunValue aRead, aValue) `isEqualElse` "The one op parsed did not have the expected run value!"
	("", afterA) `isEqualElse` "There should be no code remaining after parsing code with one nullary mock op!"

	-- Read one nullary op with some random stuff after it.
	let aPrefixReadPossibilities = readOp mockContext oneNullaryThenInvalidCode
	(1, length aPrefixReadPossibilities) `isEqualElse` "There should have only been one possibility when reading one code beginning with an op and ending with junk!"
	let (aPrefixRead, afterAPrefix) = head aPrefixReadPossibilities
	(aValue, getRunValue aPrefixRead) `isEqualElse` "The op read from mock code starting with a mock op and ending with junk did not have the expected run value!"
	assert (Map.null $ argValues aPrefixRead) "A mock op should have been read from code starting with a mock op and ending with junk without accepting any arguments!"
	(" j", afterAPrefix) `isEqualElse` "All text after the mock up should be given as the remainder after reading the first mock op!"

	-- Return no parses if the code does not start with a known op.
	readOp mockContext invalidThenOneNullaryCode `isNullElse` "The mock code with an unknown code before a known op should not be able to parse an op!"

	-- Return no parses for an empty code string.
	readOp mockContext "" `isNullElse` "Empty mock code should not have been able to parse anything!"

	-- readCode
	-- Read one nullary op from all code.
	errorOrOneOpRead <- prependToError "The mock code with one nullary op should have been parsed successfully: " $
		readCode mockContext oneNullaryOpCode
	let Right onlyOpRead = errorOrOneOpRead
	([aValue], map getRunValue onlyOpRead) `isEqualElse` "The mock code's singular op's run value was not the one expected!"

	-- Read two nullary ops from all code.
	errorOrABReadCode <- prependToError "The mock code with two nullary ops should have been parsed successfully: " $
		readCode mockContext twoNullaryOpCode
	let Right abReadCode = errorOrABReadCode
	([aValue, bValue], map getRunValue abReadCode) `isEqualElse` "The mock ops parsed from the mock code with two nullary mock ops should have had the expected run values!"

	-- Read no ops for an empty code string.
	errorOrEmptyReadCode <- prependToError "Reading empty code should not result in an error: " $
		readCode mockContext ""
	let Right emptyReadCode = errorOrEmptyReadCode
	emptyReadCode `isNullElse` "Reading empty code should result in an empty list of ops!"

	-- Err on immiedately invalid code.
	readCode mockContext invalidThenOneNullaryCode `hasErrorElse` "The mock code ending with an op but starting with junk should have failed to parse!"

	-- Err on code that starts with an op, then has invalid junk.
	readCode mockContext oneNullaryThenInvalidCode `hasErrorElse` "The mock code starting with an op and ending with junk should have failed to parse!"
