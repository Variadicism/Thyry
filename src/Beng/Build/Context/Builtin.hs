module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import Beng.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Build.Context.Builders ((=~), s, l, buildContext, define, defineUsing, defineLiteral)
import Beng.Build.Types.Cards (Card(DefCard))
import Beng.Parse.Types.Matches (Capture(..))
import Beng.Run.Ops (evaluate)
import Beng.Run.Values (Value(..), ValueType(..))
import Beng.Types.Ops.Declarations (Associativity(..))
import Beng.Types.Ops.Definitions (Definition(..))

import Data.Map ((!))
import qualified Data.Map as Map

-- constants

-- These primitive builtins are placeholders for testing.

two :: Definition
two = defineLiteral "2" 2

three :: Definition
three = defineLiteral "3" 3

add :: Definition
add = define Default
	["Augend" =~ DataType, s, l "+", s, "Addend" =~ DataType]
	\args -> do
		-- It's so annoying that the types of the arguments and the values in here are disjointed,
		-- losing all type guarantees. This will not be an issue in Beng! :)
		let (DataValue augend) = args ! "Augend"
		let (DataValue addend) = args ! "Addend"
		return $ augend + addend

subtract :: Definition
subtract = define (At add.declaration)
	["Minuend" =~ DataType, s, l "-", s, "Subtrahend" =~ DataType]
	\args -> do
		let (DataValue minuend) = args ! "Minuend"
		let (DataValue subtrahend) = args ! "Subtrahend"
		return $ minuend - subtrahend

declareVarA :: Definition  -- a := 'Value' 'Scope'
declareVarA = defineUsing (Below add.declaration) Righty
	[l "a", s, l ":=", s, "Value" =~ DataType, l "\n", s, "Scope" =~ PreOpType]
	(\args -> do
		let (OpCapture valueOp) = args ! "Value"
		-- TODO: when we have types, determine if valueOp should be evaluated or stored as an op or preop.
		value <- evaluate valueOp
		let aDefinition = defineLiteral "a" value
		return $ Map.singleton "Scope" [DefCard aDefinition])
	\args -> do
		let (OpValue scopeOp) = args ! "Scope"
		evaluate scopeOp

-- exported

context :: Context
context = buildContext [two, three, add, subtract, declareVarA]