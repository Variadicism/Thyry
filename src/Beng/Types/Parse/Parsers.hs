module Beng.Types.Parse.Parsers (
	Parse(..),
	Parses(..),
	ParseRunner,
	Parser(..),
	State(..)
) where

import Utils.Fallible (FallibleI)
import Utils.Populace (Populace)

data Parse p s t = Parse {
	parsed :: p,
	state :: s,
	target :: t }

data Parses e p s t = Parses {
	parses :: Populace (Parse p s t),
	bestError :: Maybe e }

type ParseRunner e p s t = s -> FallibleI e (Parses e p s t)

data Parser e p s t = Parser {
	name :: String,
	run :: ParseRunner e p s t }

class State p s | s -> p where
	rest :: s -> p
	indentation :: s -> Int
	indent :: s -> s
	outdent :: s -> s