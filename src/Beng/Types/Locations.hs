module Beng.Types.Locations (
	FileLocation(..),
	Location(..)
) where

import {-# SOURCE #-} Beng.Types.Things (Thing)

data Location =
	Builtin { index :: Int } |
	BuiltinArg { name :: String, parentIndex :: Int } |
	BuiltinProp { propIndex :: Int, parentIndex :: Int, one :: Thing } |
	Code { fileLocation :: FileLocation }  -- Beng needs to eliminate annoying wrapping patterns like this.

data FileLocation = FileLocation {
	file :: FilePath,
	line :: Int,
	column :: Int }