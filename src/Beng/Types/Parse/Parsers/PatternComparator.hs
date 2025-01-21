module Beng.Types.Parse.Parsers.PatternComparator (
	Comparison(..),
	State(..),
	Parse,
	Parses,
	ParseRunner,
	Parser
) where

import Beng.Types.Build.Context (Context)
import Beng.Types.Parse.Patterns (Mismatch, Pattern)
import qualified Beng.Types.Parse.Parsers as General

data Comparison = Comparison {
	sub :: [Pattern],
	super :: [Pattern] }

data State = State {
	indentation :: Int,
	rest :: Comparison,
	context :: Context }

type Parse = General.Parse Comparison State ()

type Parses = General.Parses Mismatch Comparison State ()

type ParseRunner = General.ParseRunner Mismatch Comparison State ()

type Parser = General.Parser Mismatch Comparison State ()