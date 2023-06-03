{-# LANGUAGE RecordWildCards #-}

module Beng.Types.Ops (
	Op(..),
	OpValueType(..),
	OpValue(..),
	OpArg(..),
	OpDefinition(..),
	showOpWith
) where

import Utils.Tuples (mapFst2, mapSnd2, toList2)

import Beng.Types.OpPatterns (OpPattern(..))

import Data.List.Extra (dropSuffix, replace)
import Data.Map (Map, (!?))
import qualified Data.Map as Map
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (Text)

-- private

showOpPrefixOrSuffix :: (OpPattern -> String)
showOpPrefixOrSuffix = replace "<" "\\<" . replace ">" "\\>" . show

showArgsAndSuffixesWith :: Map String String -> OMap OpArg OpPattern -> String
showArgsAndSuffixesWith argReplacements argsAndSuffixes = do
	let fillOrShowArg arg = do
		let maybeArgValue = argReplacements !? argName arg
		maybe (show arg) id maybeArgValue
	let showArgAndSuffix = toList2 . mapFst2 fillOrShowArg . mapSnd2 showOpPrefixOrSuffix
	let argsAndSuffixesShown = concatMap showArgAndSuffix $ OMap.assocs argsAndSuffixes
	concat $ dropSuffix [""] argsAndSuffixesShown

showArgsAndSuffixes :: (OMap OpArg OpPattern -> String)
showArgsAndSuffixes = showArgsAndSuffixesWith Map.empty

showOpWith :: Map String String -> Op -> String
showOpWith argReplacements Op{..} = (showOpPrefixOrSuffix $ opPrefix opDefinition) ++
	(showArgsAndSuffixesWith argReplacements $ argsAndSuffixes opDefinition)

-- types

data OpValueType = IntValueType
	deriving (Bounded, Enum, Eq, Show)

data OpValue = IntValue Int
	deriving (Eq)

data Op = Op {
	opDefinition :: OpDefinition,
	argValues :: Map String Op }

data OpArg = OpArg {
	-- In the future, arg type information will also be kept here.
	argName :: String }

data OpDefinition = OpDefinition {
	opPrefix :: OpPattern,
	argsAndSuffixes :: OMap OpArg OpPattern,
	runOpWith :: Map String OpValue -> OpValue }

-- instances

instance Show Op where
	show op = showOpWith (Map.map show $ argValues op) op

instance Show OpArg where
	show opArg = "<" ++ argName opArg ++ ">"

instance Eq OpArg where
	(==) opArg1 opArg2 = argName opArg1 == argName opArg2

instance Ord OpArg where
	(<=) opArg1 opArg2 = argName opArg1 <= argName opArg2

instance Show OpDefinition where
	show OpDefinition{..} = showOpPrefixOrSuffix opPrefix ++ showArgsAndSuffixes argsAndSuffixes

instance Show OpValue where
	show (IntValue int) = show int