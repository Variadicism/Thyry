module Beng.Parse.Types.Matches (
	CaptureType(..),
	Capture(..),
	Match(..)
) where

import {-# SOURCE #-} Beng.Types.Ops (Op)

import Data.Text.Lazy (Text)

data CaptureType =
	OpType |
	ListType { element :: CaptureType } |
	MaybeType { inner :: CaptureType }

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
	Argument { name :: String, op :: Op }