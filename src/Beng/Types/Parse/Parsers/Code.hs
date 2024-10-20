module Beng.Types.Parse.Parsers.Code (
	PrefixState(..),
	SpaceState(..),
	State(..),
	-- I can't import the general types' fields without importing the types themselves and creating ambiguity.
	-- So, I'll have to import and re-export all fields for these types aliases one by one. >:(
	Parse,
	Parses,
	ParseRunner,
	Parser,
	module Beng.Types.Parse.Parsers
) where

import Beng.Types.Build.Cards (Card)
import Beng.Types.Build.Context (Context)
import Beng.Types.Locations (FileLocation)
import Beng.Types.Ops (Op)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Parsers hiding (Parse, Parses, ParseRunner, Parser, State)
import qualified Beng.Types.Parse.Parsers as General

import Data.Map as Map
import Data.Text.Lazy (Text)

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
	rest :: Text,
	prefixState :: PrefixState,
	spaceState :: SpaceState }

type Parse t = General.Parse Text State t

type Parses t = General.Parses Text State t

type ParseRunner t = General.ParseRunner Text State t

type Parser t = General.Parser Text State t