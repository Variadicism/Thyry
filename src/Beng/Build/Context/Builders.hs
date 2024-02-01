module Beng.Build.Context.Builders (
	a,
	c,
	nc,
	cr,
	cr2,
	e,
	s,
	l,
	t,
	multi,
	patConcat,
	asOp,
	declare,
	define,
	defineRighty,
	defineUsing,
	defineLiteral,
	defineLiteralData,
	definitionOf,
	declarationOf,
	buildContextFrom
) where

import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2

import Beng.Build.Context (Context(..), pushDef)
import qualified Beng.Build.Context as Context
import Beng.Ops.Declarations (ArgContextBuilder, Associativity(..), Declaration(..), PrecedenceBound(..))
import Beng.Ops.Definitions (Definition(..), Runner)
import Beng.Parse.Types.Matches (Capture(..))
import Beng.Parse.Patterns (CharRange(..), Pattern(..))
import Beng.Run.Ops (run)
import Beng.Run.Types.Data (Data)
import Beng.Types.Locations (Location(..))
import Beng.Types.Ops (Op)

import Control.Composition ((.*))
import Data.Text.Lazy (Text)

-- private

noContexts :: ArgContextBuilder
noContexts = const $ const $ const $ return []

defineLiteralRunning :: Text -> Runner -> Location -> Definition
defineLiteralRunning literal runWith location = Definition {
	runWith, location,
	declaration = Declaration {
		location,
		pattern = Literal literal,
		associativity = Lefty {- irrelevant in nullary ops -},
		contextualize = noContexts,
		precedence = None }}

-- exported

a :: (String -> Pattern)
a = Argument

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

t :: (String -> Pattern -> Pattern)
t = NamedText

multi :: (Pattern -> Pattern)
multi = Delimited e

patConcat :: [Pattern] -> Pattern
patConcat = \case
	[] -> e
	[solo] -> solo
	(first:(second:rest)) -> And $ P2.Populace2 first second rest

asOp :: (Capture -> Op)
asOp = \case
	OpCapture op -> op
	capture -> error $
		"A builtin op assumed that an arg captured an op solo, " ++
		"but it actually captured a(n) " ++ show capture ++ "!"

declare :: PrecedenceBound -> [Pattern] -> Location -> Declaration
declare precedence subpatterns location =
	Declaration { precedence, location,
		pattern = patConcat subpatterns,
		associativity = Lefty, contextualize = noContexts }

defineUsing ::
	PrecedenceBound -> Associativity ->
	[Pattern] -> ArgContextBuilder -> Runner -> Location -> Definition
defineUsing precedence associativity subpatterns contextualize runWith location =
	Definition { location, runWith,
		declaration = Declaration {
			precedence, location, contextualize, associativity,
			pattern = patConcat subpatterns }}

define :: PrecedenceBound -> [Pattern] -> (Runner -> Location -> Definition)
define precedence subpatterns = defineUsing precedence Lefty subpatterns noContexts

defineRighty :: PrecedenceBound -> [Pattern] -> (Runner -> Location -> Definition)
defineRighty precedence subpatterns = defineUsing precedence Righty subpatterns noContexts

defineLiteral :: Text -> Op -> (Location -> Definition)
defineLiteral literal op = defineLiteralRunning literal $ const $ run op

defineLiteralData :: Text -> Data -> (Location -> Definition)
defineLiteralData literal dataValue = defineLiteralRunning literal $ const $ return dataValue


definitionOf :: Enum e => (e -> Location -> Definition) -> e -> Definition
definitionOf hangingDefinitionOf e = hangingDefinitionOf e $ Builtin $ fromEnum e

declarationOf :: Enum e => ((e -> Location -> Definition) -> e -> Declaration)
declarationOf = declaration .* definitionOf

buildContextFrom :: Enum e => (e -> Location -> Definition) -> (e -> Context)
buildContextFrom hangingDefinitionOf =
	foldl (flip pushDef) Context.empty .
		map (definitionOf hangingDefinitionOf) . enumFrom