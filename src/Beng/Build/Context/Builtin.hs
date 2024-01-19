module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import Beng.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Build.Context.Builders (a, s, l, asOp, buildContext, define, defineUsing, defineLiteral, defineLiteralData)
import Beng.Build.Types.Cards (Card(DefCard))
import Beng.Run.Ops (run)
import Beng.Types.Ops.Declarations (Associativity(..))
import Beng.Types.Ops.Definitions (Definition(..))

import Data.Map ((!))

-- constants

-- These primitive builtins are placeholders for testing.

two :: Definition
two = defineLiteralData "2" 2

three :: Definition
three = defineLiteralData "3" 3

add :: Definition
add = define Default
	[a "Augend", s, l "+", s, a "Addend"]
	\args -> do
		-- It's so annoying that the types of the arguments and the values in here are disjointed,
		-- losing all type guarantees. This will not be an issue in Beng! :)
		augend <- run $ asOp $ args ! "Augend"
		addend <- run $ asOp $ args ! "Addend"
		return $ augend + addend

subtract :: Definition
subtract = define (At add.declaration)
	[a "Minuend", s, l "-", s, a "Subtrahend"]
	\args -> do
		minuend <- run $ asOp $ args ! "Minuend"
		subtrahend <- run $ asOp $ args ! "Subtrahend"
		return $ minuend - subtrahend

declareVarA :: Definition  -- a := 'Value' 'Scope'
declareVarA = defineUsing (Below add.declaration) Righty
	[l "a", s, l ":=", s, a "Value", l "\n", s, a "Scope"]
	(\name args -> return case name of
		"Scope" -> [DefCard $ defineLiteral "a" $ asOp $ args ! "Value"]
		_ -> [])
	\args -> run $ asOp $ args ! "Scope"

-- exported

context :: Context
context = buildContext [two, three, add, subtract, declareVarA]