module Beng.Parse.Types.Matches (
	Capture(..),
	Match(..)
) where

import {-# SOURCE #-} Beng.Types.Ops (Op)
import Beng.Run.Types.Values (ValueType)

import Data.Text.Lazy (Text)

data Capture =
	OpCapture { op :: Op } |
	ListCapture { captures :: [Capture] } |
	MaybeCapture { maybeCapture :: Maybe Capture }

data Match =
	Space { text :: Text } |
	Literal { text :: Text } |
	Or { match :: Match, matchIndex :: Int, misses :: [String] } |
	And { matches :: [Match] } |
	Delimited { head :: Match, tail :: [(Match, Match)] } |
	Argument { name :: String, valueType :: ValueType, op :: Op }