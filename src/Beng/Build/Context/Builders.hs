module Beng.Build.Context.Builders (
	(=~),
	e,
	s,
	l,
	define,
	defineUsing,
	defineLiteral
) where

import Beng.Ops.Declarations (Declaration(..))
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