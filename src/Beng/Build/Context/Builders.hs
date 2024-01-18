module Beng.Build.Context.Builders (
	(=~),
	e,
	s,
	l,
	declare,
	define,
	defineRighty,
	defineUsing,
	defineLiteral,
	buildContext
) where

import Beng.Build.Context (Context(..), pushDef)
import qualified Beng.Build.Context as Context
import Beng.Ops.Declarations (ArgContextsBuilder, Associativity(..), Declaration(..), PrecedenceBound(..))
import Beng.Ops.Definitions (Definition(..), Runner)
import Beng.Parse.Patterns (Pattern(..))
import Beng.Run.Values (Data, ValueType(..))

import qualified Data.Map as Map
import Data.Text.Lazy (Text, pack)

-- private

noContexts :: ArgContextsBuilder
noContexts = const $ return Map.empty

-- exported

(=~) :: String -> ValueType -> Pattern
(=~) name valueType = Argument { name, valueType }

e :: Pattern
e = Literal ""

s :: Pattern
s = Space

l :: (Text -> Pattern)
l = Literal

declare :: PrecedenceBound -> [Pattern] -> Declaration
declare precedence subpatterns =
	Declaration { pattern = And subpatterns, associativity = Lefty, buildContexts = noContexts, precedence}

defineUsing :: PrecedenceBound -> Associativity -> [Pattern] -> ArgContextsBuilder -> (Runner -> Definition)
defineUsing precedence associativity subpatterns buildContexts = Definition $
	Declaration { pattern = And subpatterns, associativity, buildContexts, precedence }

define :: PrecedenceBound -> [Pattern] -> (Runner -> Definition)
define precedence subpatterns = defineUsing precedence Lefty subpatterns noContexts

defineRighty :: PrecedenceBound -> [Pattern] -> (Runner -> Definition)
defineRighty precedence subpatterns = defineUsing precedence Righty subpatterns noContexts

defineLiteral :: String -> Data -> Definition
defineLiteral literal dataValue = Definition {
	declaration = Declaration {
		pattern = Literal $ pack literal,
		associativity = Lefty {- irrelevant in nullary ops -},
		buildContexts = noContexts,
		precedence = None },
	runWith = const $ return dataValue }

buildContext :: [Definition] -> Context
buildContext = foldl (flip pushDef) Context.empty