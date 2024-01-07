module Beng.Build.Context.Builtin (
	context,
	-- The following shouldn't be used outside of this module except in Testing.
	e,
	s,
	l,
	define,
	defineUsing,
	defineLiteral
) where

import Prelude hiding (subtract)

import Beng.Build.Context (Context(..), push)
import Beng.Ops.Declarations (Declaration(..))
import Beng.Ops.Definitions (ArgContextsBuilder, Definition(..), Runner)
import Beng.Parse.Patterns (Pattern(..))
import qualified Beng.Parse.Types.Arguments as Arg
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
		-- TODO: if a precedence ID is not found, use the default precedence.
		length context.definitions - 1 - fromJust (findIndex (==definition) context.definitions)
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
	precedence = map toPrecedenceIDs [
		[declareVarA],       -- When the scope constructor is ready, this precedence may decrease.
		[add, subtract]]     -- Of course these have the same precedence.
	-- Ops with both a prefix and suffix have no need for precedence.