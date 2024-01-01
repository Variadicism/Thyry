module Beng.Types.Ops (
	Op(..),
	OpValuePrimitiveType(..),
	OpValue(..),
	OpArg(..),
	OpArgValues,
	PreOpContexts,
	PreOpContextsBuilder,
	OpRunner,
	OpDeclaration(..),
	OpDefinition(..),
	showOpWith,
	mustHavePrefix,
	mustHaveSuffix,
	canHavePrefix,
	canHaveSuffix,
	hasPrefix,
	hasSuffix,
	isNullary,
	showOpParens,
) where

import Utils.Lists (showWithAnd, wrap)
import Utils.Tuples (mapFst2, mapSnd2, toList2)

import Beng.Types.OpPatterns (OpPattern(..), canBePrefix, canBeSuffix, mustBePrefix, mustBeSuffix)

import Data.List.Extra (dropSuffix, replace)
import Data.Map (Map, (!?))
import qualified Data.Map as Map
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap
import Data.Maybe (fromJust)
import Data.Text.Lazy (Text, unpack)

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
showOpWith argReplacements Op{opDefinition=OpDefinition{opDeclaration=OpDeclaration{..}}} =
	showOpPrefixOrSuffix opPrefix ++ showArgsAndSuffixesWith argReplacements opArgsAndSuffixes

-- types

data OpValuePrimitiveType =
	PreOpValueType |
	OpOpValueType |
	ListOpValueType OpValuePrimitiveType |
	IntValueType
	deriving (Eq, Show)

data OpValue =
	PreOpValue PreOp |
	OpOpValue Op |
	ListOpValue [OpValue] |
	IntValue Int

data PreOp = PreOp {
	preOpArgName :: String,
	preOpContent :: Text }

data Op = Op {
	opDefinition :: OpDefinition,
	argValues :: Map String Op }

data OpArg = OpArg {
	argName :: String,
	argPrimitiveType :: OpValuePrimitiveType }

data OpDeclaration = OpDeclaration {
	opPrefix :: OpPattern,
	opArgsAndSuffixes :: OMap OpArg OpPattern }
	-- When OpDeclarations can be dynamic, equality will include location.
	deriving (Eq)

type OpArgValues = Map String OpValue

type PreOpContexts = Map String [OpDefinition]

type PreOpContextsBuilder = OpArgValues -> PreOpContexts

type OpRunner = OpArgValues -> OpValue

-- TODO: when ops can be defined dynamically, only the op declaration will apply; buildContexts and runOpWith are only to be defined for builtin ops because ops defined in code just run their body for both.
data OpDefinition = OpDefinition {
	opDeclaration :: OpDeclaration,
	buildPreOpContexts :: OpArgValues -> PreOpContexts,
	runOpWith :: OpRunner }

-- instances

instance Show PreOp where
	show PreOp{..} = wrap "'" preOpArgName ++ " := " ++
		wrap "`" (unpack preOpContent)

instance Show Op where
	show op = showOpWith (Map.map show $ argValues op) op

instance Show OpArg where
	show opArg = "<" ++ argName opArg ++ ">"

instance Eq OpArg where
	(==) opArg1 opArg2 = argName opArg1 == argName opArg2

instance Ord OpArg where
	(<=) opArg1 opArg2 = argName opArg1 <= argName opArg2

instance Eq OpDefinition where
	(==) d1 d2 = d1.opDeclaration == d2.opDeclaration

instance Show OpDefinition where
	show OpDefinition{opDeclaration=OpDeclaration{..}} =
		showOpPrefixOrSuffix opPrefix ++ showArgsAndSuffixes opArgsAndSuffixes

instance Show OpValue where
	show (PreOpValue preop) = show preop
	show (OpOpValue op) = show op
	show (ListOpValue values) = showWithAnd values
	show (IntValue int) = show int

checkPrefixWith :: (OpPattern -> Bool) -> OpDeclaration -> Bool
checkPrefixWith checker OpDeclaration{opPrefix} = checker opPrefix

checkSuffixWith :: (OpPattern -> Bool) -> OpDeclaration -> Bool
checkSuffixWith checker declaration@OpDeclaration{opArgsAndSuffixes=aas} =
	if OMap.null aas then
		checkPrefixWith checker declaration
	else
		-- `elemAt` is guaranteed to be Just when we get the last index from a non-null OMap.
		-- Beng won't have to hack around such type system inadequacies. :|
		checker $ snd $ fromJust $ aas `OMap.elemAt` (OMap.size aas - 1)

-- exported

mustHavePrefix :: (OpDeclaration -> Bool)
mustHavePrefix = checkPrefixWith mustBePrefix

mustHaveSuffix :: (OpDeclaration -> Bool)
mustHaveSuffix = checkSuffixWith mustBeSuffix

canHavePrefix :: (OpDeclaration -> Bool)
canHavePrefix = checkPrefixWith canBePrefix

canHaveSuffix :: (OpDeclaration -> Bool)
canHaveSuffix = checkSuffixWith canBeSuffix

isNullary :: (OpDeclaration -> Bool)
isNullary = OMap.null . opArgsAndSuffixes

hasPrefix :: (Op -> Bool)
-- TODO: put text captured as a field in Op and use that to tell if it actually captured a prefix.
hasPrefix = mustHavePrefix . opDeclaration . opDefinition

hasSuffix :: (Op -> Bool)
-- TODO: put text captured as a field in Op and use that to tell if it actually captured a suffix.
hasSuffix = mustHaveSuffix . opDeclaration . opDefinition

showOpParens :: Op -> String
showOpParens op = do
	let showAndParenOpIfNotNullary argOp =
		if isNullary $ opDeclaration $ opDefinition argOp
			then show argOp
			else "(" ++ showOpParens argOp ++ ")"
	let argReplacements = Map.map showAndParenOpIfNotNullary $ argValues op
	showOpWith argReplacements op