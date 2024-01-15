module Beng.Parse.Types.Parsers (
	ParseRunner,
	Parser(..),
	PrefixState(..),
	SpaceState(..),
	State(..),
	Result(..),
) where

import Beng.Build.Types.Context (Context)
import Beng.Types.Ops (Op)
import Beng.Types.Ops.Declarations (Declaration)

import Data.Text.Lazy (Text)

type ParseRunner t = State -> [Result t]

data Parser t = Parser {
	name :: String,
	run :: ParseRunner t }

{- When parsing ops, prefixed ops need to be parsed first.
   They can then be used as first arguments for non-prefixed ops.
   The PrefixStates are used for, respectively...
   - parsing a prefixed op's prefix
   - parsing any op after the prefix or first argument is captured
   - parsing a non-prefixed op's first argument -}
data PrefixState = Needed | Unneeded | AvoidingFor { firstArg :: Op }

{- The Space Pattern does more than parse whitespace; it can also accept word boundaries.
   So, the parser needs to keep track of whether the last character parsed is, respectively,...
   - a word character (requiring a non-word character next)
   - a whitespace character (satisfying the parse already), or
   - a non-word non-space character (requiring a word character next).  -}
data SpaceState = Word | Space | Punctuation
	deriving (Eq, Show)

data State = State {
	context :: Context,
	minPrecedence :: Maybe Declaration,
	maxPrecedence :: Maybe Declaration,
	indentation :: Int,
	prefixState :: PrefixState,
	spaceState :: SpaceState,
	rest :: Text }

data Result t = Result {
	state :: State,
	parsed :: Text,
	target :: t }