module Beng.Build.Context.Builders (
	a,
	c,
	nc,
	cr,
	e,
	s,
	l,
	t,
	multi,
	asOp,
	declare,
	define,
	defineRighty,
	defineUsing,
	defineLiteral,
	defineLiteralData,
	buildContext
) where

import Beng.Build.Context (Context(..), pushDef)
import qualified Beng.Build.Context as Context
import Beng.Ops.Declarations (ArgContextBuilder, Associativity(..), Declaration(..), PrecedenceBound(..))
import Beng.Ops.Definitions (Definition(..), Runner)
import Beng.Parse.Types.Matches (Capture(..))
import Beng.Parse.Patterns (CharRange(..), Pattern(..))
import Beng.Run.Ops (run)
import Beng.Run.Types.Data (Data)
import Beng.Types.Ops (Op)

import Data.Text.Lazy (Text, pack)

-- private

noContexts :: ArgContextBuilder
noContexts = const $ const $ return []

defineLiteralRunning :: String -> Runner -> Definition
defineLiteralRunning literal runner = Definition {
	declaration = Declaration {
		pattern = Literal $ pack literal,
		associativity = Lefty {- irrelevant in nullary ops -},
		contextualize = noContexts,
		precedence = None },
	runWith = runner }

-- exported

a :: (String -> Pattern)
a = Argument

c :: [CharRange] -> [Char] -> Pattern
c ranges chars = CharClass { chars, ranges, negate = False }

nc :: [CharRange] -> [Char] -> Pattern
nc ranges chars = CharClass { chars, ranges, negate = True }

cr :: Char -> Char -> CharRange
cr = CharRange

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

asOp :: (Capture -> Op)
asOp = \case
	OpCapture op -> op
	capture -> error $
		"A builtin op assumed that an arg captured an op solo, " ++
		"but it actually captured a(n) " ++ show capture ++ "!"

declare :: PrecedenceBound -> [Pattern] -> Declaration
declare precedence subpatterns =
	Declaration { pattern = And subpatterns, associativity = Lefty, contextualize = noContexts, precedence}

defineUsing :: PrecedenceBound -> Associativity -> [Pattern] -> ArgContextBuilder -> (Runner -> Definition)
defineUsing precedence associativity subpatterns contextualize = Definition $
	Declaration { pattern = And subpatterns, associativity, contextualize, precedence }

define :: PrecedenceBound -> [Pattern] -> (Runner -> Definition)
define precedence subpatterns = defineUsing precedence Lefty subpatterns noContexts

defineRighty :: PrecedenceBound -> [Pattern] -> (Runner -> Definition)
defineRighty precedence subpatterns = defineUsing precedence Righty subpatterns noContexts

defineLiteral :: String -> Op -> Definition
defineLiteral literal op = defineLiteralRunning literal $ const $ run op

defineLiteralData :: String -> (Data -> Definition)
defineLiteralData literal = defineLiteralRunning literal . const . return

buildContext :: [Definition] -> Context
buildContext = foldl (flip pushDef) Context.empty