module Beng.Build.Context.Builders (
	(=~),
	e,
	s,
	l,
	define,
	defineUsing,
	defineLiteral
) where

import Beng.Ops.Declarations (Associativity(..), Declaration(..))
import Beng.Ops.Definitions (ArgContextsBuilder, Definition(..), Runner)
import Beng.Parse.Patterns (Pattern(..))
import Beng.Run.Values (Value(..), ValueType(..))

import qualified Data.Map as Map
import Data.Text.Lazy (Text, pack)

-- exported

(=~) :: String -> ValueType -> Pattern
(=~) name valueType = Argument { name, valueType }

e :: Pattern
e = Literal ""

s :: Pattern
s = Space

l :: (Text -> Pattern)
l = Literal

defineUsing :: Associativity -> [Pattern] -> (ArgContextsBuilder -> Runner -> Definition)
defineUsing associativity subpatterns = Definition $
	Declaration { pattern = And subpatterns, associativity }

define :: [Pattern] -> (Runner -> Definition)
define subpatterns = defineUsing Lefty subpatterns (const $ const Map.empty)

defineLiteral :: String -> Value -> Definition
defineLiteral literal value = Definition {
	declaration = Declaration {
		pattern = Literal $ pack literal,
		associativity = Lefty {- irrelevant in nullary ops -} },
	buildContexts = const $ const Map.empty,
	runWith = const value }