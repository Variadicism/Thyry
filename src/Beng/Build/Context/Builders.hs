module Beng.Build.Context.Builders (
	argAt,
	c,
	nc,
	cr,
	cr2,
	e,
	s,
	l,
	textAt,
	noContext,
	multi,
	patConcat,
	asOp,
	declare,
	declareLiteral,
	define,
	defineRighty,
	defineUsing,
	defineLiteral,
	definitionOf,
	declarationOf,
	buildContextFrom
) where

import Utils.Fallible (FallibleI(..))

import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2

import Beng.Build.Context (Context(..), pushDef)
import qualified Beng.Build.Context as Context
import Beng.Ops.Types (Op)
import Beng.Ops.Declarations (ArgContextBuilder, Associativity(..), Declaration(..), PrecedenceBound(..))
import Beng.Ops.Definitions (Definition(..), Runner)
import qualified Beng.Ops.Definitions as Definition
import Beng.Parse.Types.Patterns (CharRange(..), Pattern(..))
import Beng.Types.Locations (Location(..))
import Beng.Values.Types (Type, Value(..))

import Control.Composition ((.*))
import Data.Text.Lazy (Text)

-- exported

argAt :: Location -> String -> Type -> Pattern
argAt decLoc name argType = Argument { name, argType, decLoc }

c :: [CharRange] -> Pattern
c ranges = CharClass { ranges = P.assume ranges, negate = False }

nc :: [CharRange] -> Pattern
nc ranges = CharClass { ranges = P.assume ranges, negate = True }

cr :: Char -> Char -> CharRange
cr = CharRange

cr2 :: Char -> CharRange
cr2 c = CharRange c c

e :: Pattern
e = Literal ""

s :: Pattern
s = Space

l :: (Text -> Pattern)
l = Literal

textAt :: Location -> String -> Pattern -> Pattern
textAt decLoc name subpattern = NamedText { name, subpattern, decLoc }

noContext :: ArgContextBuilder
noContext _ _ _ = Falue []

multi :: (Pattern -> Pattern)
multi = Delimited e

patConcat :: [Pattern] -> Pattern
patConcat = \case
	[] -> e
	[solo] -> solo
	(first:(second:rest)) -> And $ P2.Populace2 first second rest

asOp :: (Value -> Op)
asOp = \case
	OpValue op -> op
	value -> error $
		"A builtin op assumed that an arg was returning a OpValue, " ++
		"but it actually captured a(n) " ++ show value ++ "!"

declare :: PrecedenceBound -> [Pattern] -> Type -> Location -> Declaration
declare precedence subpatterns returnType location =
	Declaration { precedence, location, returnType,
		pattern = patConcat subpatterns,
		associativity = Lefty, contextualize = noContext }

declareLiteral :: Text -> Type -> Location -> Declaration
declareLiteral literal returnType location = Declaration {
	location,
	pattern = Literal literal,
	returnType,
	associativity = Lefty {- irrelevant in nullary ops -},
	contextualize = noContext,
	precedence = None }

defineUsing ::
	PrecedenceBound -> Associativity ->
	[Pattern] -> Type -> ArgContextBuilder -> Runner -> Location -> Definition
defineUsing precedence associativity subpatterns returnType contextualize runWith location =
	Definition { location, runWith,
		declaration = Declaration {
			precedence, location, contextualize, associativity, returnType,
			pattern = patConcat subpatterns }}

define :: PrecedenceBound -> [Pattern] -> Type -> (Runner -> Location -> Definition)
define precedence subpatterns returnType =
	defineUsing precedence Lefty subpatterns returnType noContext

defineRighty :: PrecedenceBound -> [Pattern] -> Type -> (Runner -> Location -> Definition)
defineRighty precedence subpatterns returnType = defineUsing precedence Righty subpatterns returnType noContext

defineLiteral :: Text -> Type -> Value -> Location -> Definition
defineLiteral literal valueType value location = Definition {
	runWith = const $ Falue value,
	location,
	declaration = declareLiteral literal valueType location }

definitionOf :: Enum e => (e -> Location -> Definition) -> e -> Definition
definitionOf hangingDefinitionOf e = hangingDefinitionOf e $ Builtin $ fromEnum e

declarationOf :: Enum e => ((e -> Location -> Definition) -> e -> Declaration)
declarationOf = Definition.declaration .* definitionOf

buildContextFrom :: Enum e => (e -> Location -> Definition) -> (e -> Context)
buildContextFrom hangingDefinitionOf =
	foldl (flip pushDef) Context.empty .
		map (definitionOf hangingDefinitionOf) . enumFrom