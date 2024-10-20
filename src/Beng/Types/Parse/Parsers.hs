module Beng.Types.Parse.Parsers (
	Parse(..),
	Parses(..),
	ParseRunner,
	Parser(..),
	State(..)
) where

import Utils.Populace (Populace)

import Beng.Types.Errors (Error, Fallible)

data Parse p s t = Parse {
	parsed :: p,
	state :: s,
	target :: t }

data Parses p s t = Parses {
	parses :: Populace (Parse p s t),
	bestError :: Maybe Error }

type ParseRunner p s t = s -> Fallible (Parses p s t)

data Parser p s t = Parser {
	name :: String,
	run :: ParseRunner p s t }

class State p s | s -> p where
	rest :: s -> p
	indentation :: s -> Int
	indent :: s -> s
	outdent :: s -> s