module Beng.Types.Parse.Matches (
	Parameter(..),
	DelimitedTail(..),
	Match(..)
) where

import Utils.Populace (Populace)
import Utils.Populace.Populace2 (Populace2)

import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Types.Locations (Location)
import {-# SOURCE #-} Beng.Types.Ops (Op)
import {-# SOURCE #-} Beng.Types.Things (Thing)

import Data.Text.Lazy (Text)

data Parameter = Parameter {
	decLoc :: Location,
	name :: String,
	paramType :: Thing,
	value :: Thing }

data DelimitedTail =
	DelimitedTailMatch (Populace (Match, Match)) |
	DelimitedTailMissing [Pattern.Parameter]

data Match =
	Space { text :: Text } |
	Literal { text :: Text } |
	CharClass { char :: Char } |
	NamedText { decLoc :: Location, name :: String, match :: Match } |
	Or { match :: Match, matchIndex :: Int, misses :: [Pattern.Parameter] } |
	And { matches :: Populace2 Match } |
	Delimited { head :: Match, tail :: DelimitedTail } |
	Argument { decLoc :: Location, name :: String, argType :: Thing, op :: Op }