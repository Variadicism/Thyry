module Beng.Parse.Types.Matches (
	Match(..)
) where

import qualified Beng.Parse.Types.Arguments as Arg

import Data.Text.Lazy (Text)

data Match =
	Space { text :: Text } |
	Literal { text :: Text } |
	Or { match :: Match, matchIndex :: Int } |
	And { matches :: [Match] } |
	Delimited { head :: Match, tail :: [(Match, Match)] } |
	Argument { arg :: Arg.Match }