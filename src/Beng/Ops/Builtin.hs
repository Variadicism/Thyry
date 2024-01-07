module Beng.Ops.Builtin (
	builtinOps,
	builtinPrecedence,
	builtinContext,
	e,
	s,
	l,
	define,
	defineUsing
) where

import Prelude hiding (subtract)

import Beng.Ops.Declarations (Declaration(..))
import Beng.Ops.Definitions (ArgContextsBuilder, Definition(..), Runner)
import Beng.Parse.Patterns (Pattern(..))
import qualified Beng.Parse.Types.Arguments as Arg
import Beng.Parse.Context (Context(..), push)
import Beng.Run.Ops (run)
import Beng.Run.Values (Value(..), ValueType(..))

import Data.List (findIndex)
import Data.Map ((!))
import qualified Data.Map as Map
import Data.Maybe (fromJust)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text.Lazy (Text, pack)

-- private

toPrecedenceIDs :: [Definition] -> Set Int
toPrecedenceIDs definitions = do
	let toPrecedenceID definition =
		length builtinOps - 1 - fromJust (findIndex (==definition) builtinOps)
	Set.fromList $ map toPrecedenceID definitions

-- builders

e :: Pattern
e = Empty

s :: Pattern
s = Space

l :: (Text -> Pattern)
l = Literal

defineUsing :: [Pattern] -> (ArgContextsBuilder -> Runner -> Definition)
defineUsing subpatterns = Definition (Declaration $ And subpatterns)

define :: [Pattern] -> (Runner -> Definition)
define subpatterns = defineUsing subpatterns (const $ const Map.empty)

defineLiteral :: String -> Value -> Definition
defineLiteral literal value = Definition {
	declaration = Declaration {
		pattern = Literal $ pack literal },
	buildContexts = const $ const Map.empty,
	runWith = const value }

defArg :: String -> ValueType -> Pattern
defArg name valueType = Argument $ Arg.Definition { name, valueType }

-- builtin ops

-- These primitive builtins are placeholders for testing.

two :: Definition
two = defineLiteral "2" $ IntValue 2

three :: Definition
three = defineLiteral "3" $ IntValue 3

add :: Definition
add = define
	[defArg "Augend" IntType, s, l "+", s, defArg "Addend" IntType]
	\args -> do
		-- It's so annoying that the types of the arguments and the values in here are disjointed,
		-- losing all type guarantees. This will not be an issue in Beng! :)
		let (IntValue augend) = args ! "Augend"
		let (IntValue addend) = args ! "Addend"
		IntValue $ augend + addend

subtract :: Definition
subtract = define
	[defArg "Minuend" IntType, s, l "-", s, defArg "Subtrahend" IntType]
	\args -> do
		let (IntValue minuend) = args ! "Minuend"
		let (IntValue subtrahend) = args ! "Subtrahend"
		IntValue $ minuend - subtrahend

declareVarA :: Definition  -- a := 'Value' 'Scope'
declareVarA = defineUsing
	[l "a", s, l ":=", s, defArg "Value" IntType, l "\n", s, defArg "Scope" PreOpType]
	(\args context -> Map.singleton "Scope" $
		push (define [l "a"] $ const $ args ! "Value") context)
	\args -> do
		let (OpValue scope) = args ! "Scope"
		run scope

-- These builtins are currently placeholders for testing the parsing and running capabilities.
builtinOps :: [Definition]
builtinOps = [
	two, three,
	add, subtract,
	declareVarA ]

builtinPrecedence :: [Set Int]
builtinPrecedence = map toPrecedenceIDs [
	[declareVarA],       -- When the scope constructor is ready, this precedence may decrease.
	[add, subtract]]     -- Of course these have the same precedence.
-- Ops with both a prefix and suffix have no need for precedence.

builtinContext :: Context
builtinContext = Context {
	precedence = builtinPrecedence,
	definitions = builtinOps }