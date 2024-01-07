module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import Beng.Build.Context (Context(..), push)
import Beng.Build.Context.Builders ((=~), s, l, define, defineUsing, defineLiteral)
import Beng.Run.Ops (run)
import Beng.Run.Values (Value(..), ValueType(..))
import Beng.Types.Ops.Definitions (Definition(..))

import Data.Map ((!))
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set

-- constants

-- These primitive builtins are placeholders for testing.

two :: Definition
two = defineLiteral "2" $ IntValue 2

three :: Definition
three = defineLiteral "3" $ IntValue 3

add :: Definition
add = define
	["Augend" =~ IntType, s, l "+", s, "Addend" =~ IntType]
	\args -> do
		-- It's so annoying that the types of the arguments and the values in here are disjointed,
		-- losing all type guarantees. This will not be an issue in Beng! :)
		let (IntValue augend) = args ! "Augend"
		let (IntValue addend) = args ! "Addend"
		IntValue $ augend + addend

subtract :: Definition
subtract = define
	["Minuend" =~ IntType, s, l "-", s, "Subtrahend" =~ IntType]
	\args -> do
		let (IntValue minuend) = args ! "Minuend"
		let (IntValue subtrahend) = args ! "Subtrahend"
		IntValue $ minuend - subtrahend

declareVarA :: Definition  -- a := 'Value' 'Scope'
declareVarA = defineUsing
	[l "a", s, l ":=", s, "Value" =~ IntType, l "\n", s, "Scope" =~ PreOpType]
	(\args context -> do
		let aDefinition = define [l "a"] $ const $ args ! "Value"
		Map.singleton "Scope" $ push aDefinition context)
	\args -> do
		let (OpValue scope) = args ! "Scope"
		run scope

-- exported

context :: Context
context = Context { precedence, definitions } where
	-- These builtins are currently placeholders for testing the parsing and running capabilities.
	definitions :: [Definition]
	definitions = [
		two, three,
		add, subtract,
		declareVarA ]

	precedence :: [Set Int]
	precedence = [
		Set.singleton 0,         -- `declareVarA`
		Set.fromList [1, 2]]     -- `add` and `subtract`
	-- Ops with both a prefix and suffix like `two` and `three` have no need for precedence.