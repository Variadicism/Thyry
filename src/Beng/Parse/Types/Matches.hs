module Beng.Parse.Types.Matches (
	Capture(..),
	Match(..)
) where

import {-# SOURCE #-} Beng.Types.Ops (Op)

import Data.Text.Lazy (Text)

data Capture =
	OpCapture { op :: Op } |
	-- This name refers to the "string" in Beng, not in Haskell.
	StringCapture { text :: Text } |
	ListCapture { captures :: [Capture] } |
	MaybeCapture { maybeCapture :: Maybe Capture }

data Match =
	Space { text :: Text } |
	Literal { text :: Text } |
	CharClass { char :: Char } |
	NamedText { name :: String, match :: Match } |
	Or { match :: Match, matchIndex :: Int, misses :: [String] } |
	And { matches :: [Match] } |
	Delimited { head :: Match, tail :: [(Match, Match)] } |
	Argument { name :: String, op :: Op }