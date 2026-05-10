module Beng.Types.Parse.Parsers.PatternComparator (
	Comparison(..),
	ComparatorState(..),
	State,
	Parse,
	Parses,
	ParseRunner,
	Comparator
) where

import Beng.Types.Build.TypeTest (TypeTest)
import Beng.Types.Parse.Patterns (Mismatch, SomePattern)
import qualified Beng.Types.Parse.Parsers as General
import Beng.Types.Parse.Parsers.Code (SpaceState)

data Comparison = Comparison {
	candidate :: [SomePattern],
	requirement :: [SomePattern] }

data ComparatorState = ComparatorState {
	indentation :: Int,
	-- Temporary comparator heuristic to distinguish leading optionals from interior ones.
	atStart :: Bool,
	spaceState :: SpaceState,
	rest :: Comparison,
	checkArgTypes :: Bool,
	test :: TypeTest }

type State = ComparatorState
type Parse = General.Parse Comparison ComparatorState ()
type Parses = General.Parses Mismatch Comparison ComparatorState ()
type ParseRunner = General.ParseRunner Mismatch Comparison ComparatorState ()
type Comparator = General.Parser Mismatch Comparison ComparatorState ()
