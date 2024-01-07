{- This should be separated into many files, but these types are heavily interdependent
   and HS-Boot is such evil cryptic garbage that I'm going to throw a (second) fit if
   I ever see the text "Unexpected non-cycle" in my terminal again.
   So, GHC forces me to put these interdependent types into one monolithic file. Great.
   At least I can be petty and divide the file up with big separator comments. -}

module Beng.Types (
	-- Ops
	PreOp(..),
	Op(..),
	-- Declarations
	Declaration(..),
	-- Definitions
	Definition(..),
	ArgContextsBuilder,
	Runner,
	-- Args
	Arg(..),
	ArgMatch(..),
	-- Values
	ValueType(..),
	Value(..),
	-- Patterns
	Pattern(..),
	-- Matches
	Match(..),
	-- Context
	Context(..),
	SpaceState(..)
) where

import Data.Map (Map)
import Data.Set (Set)
import Data.Text.Lazy (Text)


----------------------- Ops ------------------------


data PreOp = PreOp {
	name :: String,
	content :: Text }

data Op = Op {
	definition :: Definition,
	match :: Match }


------------------- Declarations -------------------


data Declaration = Declaration {
	pattern :: Pattern }


------------------- Definitions --------------------


type ArgContextsBuilder = Map String Value -> Context -> Map String Context

type Runner = Map String Value -> Value

-- TODO: when ops can be defined dynamically, only the op declaration will apply; buildContexts and runOpWith are only to be defined for builtin ops because ops defined in code just run their body for both.
data Definition = Definition {
	declaration :: Declaration,
	buildContexts :: ArgContextsBuilder,
	runWith :: Runner }


----------------------- Args -----------------------


data Arg = Arg {
	name :: String,
	valueType :: ValueType }

data ArgMatch = ArgMatch {
	arg :: Arg,
	op :: Maybe Op,
	text :: Text }


---------------------- Values ----------------------


data ValueType =
	PreOpType |
	OpType |
	ListType { element :: ValueType } |
	MaybeType { inner :: ValueType } |
	IntType

data Value =
	PreOpValue { preOp :: PreOp } |
	OpValue { op :: Op } |
	ListValue { values :: [Value] } |
	MaybeValue { maybeValue :: Maybe Value } |
	IntValue { int :: Int }


--------------------- Patterns ---------------------


data Pattern =
	Empty |
	Space |
	Literal { literal :: Text } |
	Or { subpatterns :: [Pattern] } |
	And { subpatterns :: [Pattern] } |
	Delimited { delimiter :: Pattern, delimitend :: Pattern } |
	ArgPattern { arg :: Arg }


--------------------- Matches ----------------------


data Match =
	EmptyMatch |
	SpaceMatch { text :: Text } |
	LiteralMatch { text :: Text } |
	OrMatch { submatch :: Match, submatchIndex :: Int } |
	AndMatch { submatches :: [Match] } |
	-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me! :P
	DelimitedMatch { head :: Match, tail :: [(Match, Match)] } |
	ArgPatternMatch { arg :: ArgMatch  }


--------------------- Context ----------------------


{- The Space Pattern does more than parse whitespace; it can also accept word boundaries.
   So, to parse correctly, the parser needs to keep track of whether the last character parsed is...
   - a word character (requiring a non-word character next)
   - a space character (satisfying the parse already), or
   - a non-word non-space character (requiring a word character next).  -}
data SpaceState = Word | Whitespace | Other

data Context = Context {
{- Defintion end-indices grouped by precedence.
   Lower index -> lower/broader precedence
   The value is the index _from the end_ of the list of definitions.
       This is because new definitions are prepended, so the indexes shift,
       but indexes relative to the end of the list do not. -}
	precedence :: [Set Int],
{- Definitions stack
   Lower index -> defined later/closer (first dibs) -}
	definitions :: [Definition],
	spaceState :: SpaceState }