module Beng.Types.Parse.Parsers.PatternComparator (
	Comparison(..),
	State(..),
	Parse,
	Parses,
	ParseRunner,
	Parser
) where

import Beng.Types.Parse.Patterns (Mismatch, Pattern)
import Beng.Types.SatisfactionTest (SatisfactionTest)
import qualified Beng.Types.Parse.Parsers as General

data Comparison = Comparison {
	sub :: [Pattern],
	super :: [Pattern] }

data State = State {
	indentation :: Int,
	rest :: Comparison,
	test :: SatisfactionTest }

type Parse = General.Parse Comparison State ()

type Parses = General.Parses Mismatch Comparison State ()

type ParseRunner = General.ParseRunner Mismatch Comparison State ()

type Parser = General.Parser Mismatch Comparison State ()