module Beng.Types.Locations (
	FileLocation(..),
	Location(..)
) where

data Location =
	Builtin { index :: Int } |
	Code { fileLocation :: FileLocation }  -- Beng needs to eliminate annoying wrapping patterns like this.

data FileLocation = FileLocation {
	file :: FilePath,
	line :: Int,
	column :: Int }