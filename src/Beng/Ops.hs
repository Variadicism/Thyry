{-# LANGUAGE RecordWildCards #-}

module Beng.Ops (
	runOp,
	hasPrefix,
	isNullary,
	showOpParens,
	newLiteralOp,
) where

import Prelude hiding (lookup)

import Utils.Lists
import Utils.Messaging
import Utils.Tuples

import Beng.Types.OpPatterns (OpPattern(..))
import Beng.Types.Ops (Op(..), OpValue, OpDeclaration(..), OpDefinition(..), showOpWith)

import Data.List (intercalate)
import Data.List.Extra (replace)
import Data.Map (Map, lookup)
import qualified Data.Map as Map (empty, map)
import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap (assocs, empty, null)
import Data.Text.Lazy (pack)

-- builtins

-- There is a subtly represented but CRUCIAL property of Beng noted here. Notice how running an op returns a value -- JUST a value. It is INFALLIBLE! This should ALWAYS HOLD TRUE! If this language compiles, it should be able to run without EVER throwing an error!! Errors will be handled inside the program and can print messages and close or whatever, but the program CANNOT CRASH!
runOp :: Op -> OpValue
runOp Op{opDefinition=OpDefinition{..},..} = runOpWith $ Map.map runOp argValues

-- utilities

hasPrefix :: (OpDeclaration -> Bool)
hasPrefix = (OpEmpty/=) . opPrefix

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
