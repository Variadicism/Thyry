module Beng.Types.Parse.Parsers.Code (
	PrefixState(..),
	SpaceState(..),
	spaceStateOfChar,
	formsBoundary,
	State(..),
	-- I can't import the general types' fields without importing the types themselves and creating ambiguity.
	-- So, I'll have to import and re-export all fields for these types aliases one by one. >:(
	Parse,
	Parses,
	ParseRunner,
	Parser,
	module Beng.Types.Parse.Parsers
) where

import {-# SOURCE #-} Beng.Types.Operators (SomeOperator)
import {-# SOURCE #-} Beng.Types.Build.Context (Context)
import {-# SOURCE #-} Beng.Types.Errors (Error)
import Beng.Types.Locations (FileLocation)
import {-# SOURCE #-} Beng.Types.Invocations (SomeInvocation)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Parsers hiding (Parse, Parses, ParseRunner, Parser, State)
import qualified Beng.Types.Parse.Parsers as General

import Data.Char (isAlphaNum, isSpace)
import Data.Map as Map
import Data.Text.Lazy (Text)

{- When parsing ops, prefixed ops need to be parsed first.
   They can then be used as first arguments for non-prefixed ops.
   The PrefixStates are used for, respectively...
   - parsing a prefixed op's prefix
   - parsing any op after the prefix or first argument is captured
   - parsing a non-prefixed op's first argument -}
data PrefixState = Needed | Unneeded | AvoidingFor { firstArg :: SomeInvocation }

{- The Space Pattern does more than parse whitespace; it can also accept word boundaries.
   So, the parser needs to keep track of whether the last character parsed is, respectively,...
   - a word character (requiring a non-word character next)
   - a whitespace character (satisfying the parse already), or
   - a non-word non-space character (requiring a word character next).  -}
data SpaceState = Word | Space | Punctuation
	deriving (Eq, Ord, Show)

spaceStateOfChar :: Char -> SpaceState
spaceStateOfChar c
	| isSpace c = Space
	| isAlphaNum c = Word
	| otherwise = Punctuation

formsBoundary :: SpaceState -> SpaceState -> Bool
formsBoundary prevState nextState =
	prevState == Space || (prevState == Word) /= (nextState == Word)

data State = State {
	location :: FileLocation,
	context :: Context,
	parent :: Maybe SomeOperator,  -- TODO: turn into a stack of op arguments for debugging
	maxPrecedence :: Maybe SomeOperator,
	arguments :: Map String Match.Argument,
	indentation :: Int,
	rest :: Text,
	prefixState :: PrefixState,
	spaceState :: SpaceState }

type Parse t = General.Parse Text State t

type Parses t = General.Parses Error Text State t

type ParseRunner t = General.ParseRunner Error Text State t

type Parser t = General.Parser Error Text State t
