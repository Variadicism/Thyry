module Beng.Parse.Types.Parsers (
	Results,
	ParseRunner,
	Parser(..),
	PrefixState(..),
	SpaceState(..),
	State(..),
	Parse(..),
) where

import Utils.Populace (Populace)

import Beng.Build.Types.Cards (Card)
import Beng.Build.Types.Context (Context)
import Beng.Parse.Types.Matches (Capture)
import Beng.Types.Locations (Location)
import Beng.Types.Ops (Op)
import Beng.Types.Errors (Fallible)

import Data.Map as Map
import Data.Text.Lazy (Text)

-- Fallible = FallibleI Beng.Error
type Results t = Fallible (Populace (Parse t))

type ParseRunner t = State -> Results t

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
	location :: Location,
	context :: Context,
	parent :: Maybe Card,
	maxPrecedence :: Maybe Card,
	arguments :: Map String Capture,
	indentation :: Int,
	prefixState :: PrefixState,
	spaceState :: SpaceState,
	rest :: Text }

data Parse t = Parse {
	state :: State,
	parsed :: Text,
	target :: t }