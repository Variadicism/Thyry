module Ops (
	OpDefinition(..),
	OpArg(..),
	Op(..),
	runOp,
	hasPrefix
) where

import Prelude hiding (lookup)

import Utils.Lists
import Utils.Messaging
import Utils.Tuples

import Values

import Data.List (intercalate)
import Data.Map (Map, lookup)
import qualified Data.Map as Map (empty, map)
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap (assocs)
import Data.String.Utils (replace)

-- private utils

showOpPrefixOrSuffix :: (String -> String)
showOpPrefixOrSuffix = replace "<" "\\<" . replace ">" "\\>"

showArgsAndSuffixesWith :: Map String String -> OMap OpArg String -> String
showArgsAndSuffixesWith argReplacements argsAndSuffixes = do
	let fillOrShowArg = \arg -> do
		let maybeArgValue = argName arg `lookup` argReplacements
		debugM ("Maybe replacing arg " ++ msgShow arg ++ " with value " ++ msgShow maybeArgValue ++ "...")
		maybe (show arg) show maybeArgValue
	let showArgAndSuffix = toList2 . mapFst2 fillOrShowArg . mapSnd2 showOpPrefixOrSuffix
	let argsAndSuffixesShown = concat $ map showArgAndSuffix $ OMap.assocs argsAndSuffixes
	let argsAndSuffixesShownWithoutTrailingEmptyString = dropSuffix [""] argsAndSuffixesShown
	intercalate " " argsAndSuffixesShownWithoutTrailingEmptyString

showArgsAndSuffixes :: (OMap OpArg String -> String)
showArgsAndSuffixes = showArgsAndSuffixesWith Map.empty

-- OpArg

data OpArg = OpArg {
	-- In the future, arg type information will also be kept here.
	argName :: String }

instance Show OpArg where
	show opArg = "<" ++ argName opArg ++ ">"

instance Eq OpArg where
	(==) opArg1 opArg2 = argName opArg1 == argName opArg2

instance Ord OpArg where
	(<=) opArg1 opArg2 = argName opArg1 <= argName opArg2

-- OpDefinition

data OpDefinition = OpDefinition {
	opPrefix :: String,
	argsAndSuffixes :: OMap OpArg String,
	runOpWith :: Map String Value -> Value }

instance Show OpDefinition where
	show definition = (showOpPrefixOrSuffix $ opPrefix definition) ++ (showArgsAndSuffixes $ argsAndSuffixes definition)

-- Op

data Op = Op {
	opDefinition :: OpDefinition,
	argValues :: Map String Op }

instance Show Op where
	show op = do
		let argReplacements = Map.map show $ argValues op
		(opPrefix $ opDefinition op) ++ (showArgsAndSuffixesWith argReplacements $ argsAndSuffixes $ opDefinition op)

-- utils

-- There is a subtly represented but CRUCIAL property of Beng noted here. Notice how running an op returns a value -- JUST a value. It is INFALLIBLE! This should ALWAYS HOLD TRUE! If this language compiles, it should be able to run without EVER throwing an error!! Errors will be handled inside the program and can print messages and close or whatever, but the program CANNOT CRASH!
runOp :: Op -> Value
runOp op = runOpWith (opDefinition op) (Map.map runOp $ argValues op)

hasPrefix :: (OpDefinition -> Bool)
hasPrefix = not . null . opPrefix
