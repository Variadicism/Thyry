module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import Beng.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Build.Context.Builders (a, c, cr, e, s, l, t, asOp, buildContext, define, defineUsing, defineLiteral)
import Beng.Build.Types.Cards (Card(DefCard))
import Beng.Parse.Types.Matches (Capture(..))
import Beng.Parse.Types.Patterns (Pattern(..))
import Beng.Run.Ops (run)
import Beng.Types.Ops.Declarations (Associativity(..))
import Beng.Types.Ops.Definitions (Definition(..))

import Data.Map ((!))
import Data.Text.Lazy (unpack)

-- constants

-- These primitive builtins are placeholders for testing.

integers :: Definition
integers = define None
	[t "Integer" $ Delimited e $ c [cr '0' '9'] []]
	\args -> do
		let (StringCapture text) = args ! "Integer"
		-- `read` is safe because we only match '0'-'9'.
		return (read $ unpack text :: Int)

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

valueName :: Pattern
valueName = do
	let uppercaseLetter = c [cr 'A' 'Z'] []
	let letter = c [cr 'A' 'Z', cr 'a' 'z'] []
	let capitalizedWord = And [uppercaseLetter, Or [e, Delimited e letter]]
	Delimited { delimiter = Space, delimitend = capitalizedWord }

defineValue :: Definition  -- "Name" := 'Value' 'Scope'
defineValue = defineUsing (Below add.declaration) Righty
	[t "Name" valueName, s, l ":=", s, a "Value", s, a "Scope"]
	(\name args -> return case name of
		"Scope" -> do
			let (StringCapture name) = args ! "Name"
			[DefCard $ defineLiteral (unpack name) $ asOp $ args ! "Value"]
		_ -> [])
	\args -> run $ asOp $ args ! "Scope"

-- exported

context :: Context
context = buildContext [integers, add, subtract, defineValue]