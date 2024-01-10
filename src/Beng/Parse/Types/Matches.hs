module Beng.Parse.Types.Matches (
	Match(..)
) where

import {-# SOURCE #-} Beng.Types.Ops (Op)
import Data.Text.Lazy (Text)

data Match =
	Space { text :: Text } |
	Literal { text :: Text } |
	Or { match :: Match, matchIndex :: Int } |
	And { matches :: [Match] } |
	Delimited { head :: Match, tail :: [(Match, Match)] } |
	Argument { name :: String, op :: Op }