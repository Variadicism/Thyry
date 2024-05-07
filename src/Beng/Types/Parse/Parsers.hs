module Beng.Types.Parse.Parsers (
	Parses(..),
	ParseRunner,
	Parser(..),
	PrefixState(..),
	SpaceState(..),
	State(..),
	Parse(..),
) where

import Utils.Populace (Populace)

import Beng.Types.Build.Cards (Card)
import Beng.Types.Build.Context (Context)
import Beng.Types.Locations (FileLocation)
import Beng.Types.Ops (Op)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Errors (Error, Fallible)

import Data.Map as Map
import Data.Text.Lazy (Text)

data Parses t = Parses {
	parses :: Populace (Parse t),
	bestError :: Maybe Error }

type ParseRunner t = State -> Fallible (Parses t)

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
	location :: FileLocation,
	context :: Context,
	parent :: Maybe Card,  -- TODO: turn into a stack of op arguments for debugging
	maxPrecedence :: Maybe Card,
	arguments :: Map String Match.Parameter,
	indentation :: Int,
	prefixState :: PrefixState,
	spaceState :: SpaceState,
	rest :: Text }

data Parse t = Parse {
	state :: State,
	parsed :: Text,
	target :: t }