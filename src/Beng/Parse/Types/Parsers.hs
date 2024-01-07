module Beng.Parse.Types.Parsers (
	ParseRunner,
	Parser(..),
	Result(..),
	SpaceState(..),
	State(..)
) where

import Beng.Parse.Types.Context (Context)

import Data.Text.Lazy (Text)

type ParseRunner t = State -> [Result t]

data Parser t = Parser {
	name :: String,
	run :: ParseRunner t }

{- The Space Pattern does more than parse whitespace; it can also accept word boundaries.
   So, the parser needs to keep track of whether the last character parsed is, respectively,...
   - a word character (requiring a non-word character next)
   - a whitespace character (satisfying the parse already), or
   - a non-word non-space character (requiring a word character next).  -}
data SpaceState = Word | Space | Punctuation
	deriving (Eq, Show)

data State = State {
	context :: Context,
	spaceState :: SpaceState,
	rest :: Text }

data Result t = Result {
	state :: State,
	parsed :: Text,
	target :: t }