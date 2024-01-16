module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import Beng.Build.Context (Context(..), PrecedenceBound(..), pushDef)
import Beng.Build.Context.Builders ((=~), s, l, buildContext, define, defineUsing, defineLiteral)
import Beng.Run.Ops (run)
import Beng.Run.Values (Value(..), ValueType(..))
import Beng.Types.Ops.Declarations (Associativity(..))
import Beng.Types.Ops.Definitions (Definition(..))

import Data.Map ((!))
import qualified Data.Map as Map

-- constants

-- These primitive builtins are placeholders for testing.

two :: Definition
two = defineLiteral "2" $ IntValue 2

three :: Definition
three = defineLiteral "3" $ IntValue 3

add :: Definition
add = define Default
	["Augend" =~ IntType, s, l "+", s, "Addend" =~ IntType]
	\args -> do
		-- It's so annoying that the types of the arguments and the values in here are disjointed,
		-- losing all type guarantees. This will not be an issue in Beng! :)
		let (IntValue augend) = args ! "Augend"
		let (IntValue addend) = args ! "Addend"
		return $ IntValue $ augend + addend

subtract :: Definition
subtract = define (At add.declaration)
	["Minuend" =~ IntType, s, l "-", s, "Subtrahend" =~ IntType]
	\args -> do
		let (IntValue minuend) = args ! "Minuend"
		let (IntValue subtrahend) = args ! "Subtrahend"
		return $ IntValue $ minuend - subtrahend

declareVarA :: Definition  -- a := 'Value' 'Scope'
declareVarA = defineUsing (Below add.declaration) Righty
	[l "a", s, l ":=", s, "Value" =~ IntType, l "\n", s, "Scope" =~ PreOpType]
	(\context args -> do
		value <- run $ args ! "Value"
		let aDefinition = defineLiteral "a" value
		return $ Map.singleton "Scope" $ pushDef aDefinition context)
	\args -> do
		let (OpValue scope) = args ! "Scope"
		run scope

-- exported

context :: Context
context = buildContext [two, three, add, subtract, declareVarA]