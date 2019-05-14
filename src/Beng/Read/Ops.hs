module Beng.Read.Ops (
	OpDefinition(..),
	OpArg(..),
	Op(..),
	runOp,
	hasPrefix,
	showOpParens,
	newLiteralOp,
) where

import Prelude hiding (lookup)

import Utils.Lists
import Utils.Messaging
import Utils.Tuples

import Beng.Read.OpPatterns (OpPattern(OpEmpty, OpLiteral))
import Beng.Read.Values

import Data.List (intercalate)
import Data.Map (Map, lookup)
import qualified Data.Map as Map (empty, map)
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap (assocs, empty, null)
import Data.String.Utils (replace)
import Data.Text.Lazy (pack)

-- private utils

showOpPrefixOrSuffix :: (OpPattern -> String)
showOpPrefixOrSuffix = replace "<" "\\<" . replace ">" "\\>" . show

showArgsAndSuffixesWith :: Map String String -> OMap OpArg OpPattern -> String
showArgsAndSuffixesWith argReplacements argsAndSuffixes = do
	let fillOrShowArg arg = do
		let maybeArgValue = argName arg `lookup` argReplacements
		maybe (show arg) id maybeArgValue
	let showArgAndSuffix = toList2 . mapFst2 fillOrShowArg . mapSnd2 showOpPrefixOrSuffix
	let argsAndSuffixesShown = concat $ map showArgAndSuffix $ OMap.assocs argsAndSuffixes
	concat $ dropSuffix [""] argsAndSuffixesShown

showArgsAndSuffixes :: (OMap OpArg OpPattern -> String)
showArgsAndSuffixes = showArgsAndSuffixesWith Map.empty

showOpWith :: Map String String -> Op -> String
showOpWith argReplacements op = (showOpPrefixOrSuffix $ opPrefix $ opDefinition op) ++ (showArgsAndSuffixesWith argReplacements $ argsAndSuffixes $ opDefinition op)

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
	opPrefix :: OpPattern,
	argsAndSuffixes :: OMap OpArg OpPattern,
	runOpWith :: Map String Value -> Value }

instance Show OpDefinition where
	show definition = (showOpPrefixOrSuffix $ opPrefix definition) ++ (showArgsAndSuffixes $ argsAndSuffixes definition)

-- Op

data Op = Op {
	opDefinition :: OpDefinition,
	argValues :: Map String Op }

instance Show Op where
	show op = showOpWith (Map.map show $ argValues op) op

-- utils

-- There is a subtly represented but CRUCIAL property of Beng noted here. Notice how running an op returns a value -- JUST a value. It is INFALLIBLE! This should ALWAYS HOLD TRUE! If this language compiles, it should be able to run without EVER throwing an error!! Errors will be handled inside the program and can print messages and close or whatever, but the program CANNOT CRASH!
runOp :: Op -> Value
runOp op = runOpWith (opDefinition op) (Map.map runOp $ argValues op)

hasPrefix :: (OpDefinition -> Bool)
hasPrefix = (OpEmpty/=) . opPrefix

isNullary :: (OpDefinition -> Bool)
isNullary = OMap.null . argsAndSuffixes

showOpParens :: Op -> String
showOpParens op = do
	let showAndParenOpIfNotNullary argOp =
		if isNullary $ opDefinition argOp
			then show argOp
			else "(" ++ showOpParens argOp ++ ")"
	let argReplacements = Map.map showAndParenOpIfNotNullary $ argValues op
	showOpWith argReplacements op

newLiteralOp :: String -> Value -> OpDefinition
newLiteralOp literal value = OpDefinition {
		opPrefix = OpLiteral $ pack literal,
		argsAndSuffixes = OMap.empty,
		runOpWith = const value }
