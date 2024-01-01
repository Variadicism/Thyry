module Beng.Ops (
	runOp,
	hasPrefix,
	hasSuffix,
	isNullary,
	showOpParens,
	newLiteralOp,
) where

import Prelude hiding (lookup)

import Beng.Read.OpPatterns (isPrefix, isSuffix)
import Beng.Types.OpPatterns (OpPattern(..))
import Beng.Types.Ops (Op(..), OpValue, OpDeclaration(..), OpDefinition(..), showOpWith)

import qualified Data.Map as Map (empty, map)
import qualified Data.Map.Ordered as OMap
import Data.Maybe (fromJust)  -- gross
import Data.Text.Lazy (pack)

-- builtins

-- There is a subtly represented but CRUCIAL property of Beng noted here. Notice how running an op returns a value -- JUST a value. It is INFALLIBLE! This should ALWAYS HOLD TRUE! If this language compiles, it should be able to run without EVER throwing an error!! Errors will be handled inside the program and can print messages and close or whatever, but the program CANNOT CRASH!
runOp :: Op -> OpValue
runOp Op{opDefinition=OpDefinition{..},..} = runOpWith $ Map.map runOp argValues

-- utilities

hasPrefix :: OpDeclaration -> Bool
hasPrefix OpDeclaration{opPrefix} = isPrefix opPrefix

hasSuffix :: OpDeclaration -> Bool
hasSuffix declaration@OpDeclaration{opArgsAndSuffixes=aas} =
	if OMap.null aas then
		hasPrefix declaration
	else
		-- `elemAt` is guaranteed to be Just when we get the last index from a non-null OMap.
		-- Beng won't have to hack around such type system inadequacies. :|
		isSuffix $ snd $ fromJust $ aas `OMap.elemAt` (OMap.size aas - 1)

isNullary :: (OpDeclaration -> Bool)
isNullary = OMap.null . opArgsAndSuffixes

showOpParens :: Op -> String
showOpParens op = do
	let showAndParenOpIfNotNullary argOp =
		if isNullary $ opDeclaration $ opDefinition argOp
			then show argOp
			else "(" ++ showOpParens argOp ++ ")"
	let argReplacements = Map.map showAndParenOpIfNotNullary $ argValues op
	showOpWith argReplacements op

newLiteralOp :: String -> OpValue -> OpDefinition
newLiteralOp literal value = OpDefinition {
	opDeclaration = OpDeclaration {
		opPrefix = OpLiteral $ pack literal,
		opArgsAndSuffixes = OMap.empty },
	buildPreOpContexts = const Map.empty,
	runOpWith = const value }
