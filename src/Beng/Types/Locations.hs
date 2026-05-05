module Beng.Types.Locations (
	FileLocation(..),
	Location(..)
) where

data Location =
	Builtin { index :: Int } |
	BuiltinArg { name :: String, parentIndex :: Int } |
	BuiltinProp {
		propIndex :: Int,
		parentIndex :: Int,
		one :: Location
	} |  -- TODO: revisit prop owner identity; using Location avoids recursive Eq for now.
	Code { fileLocation :: FileLocation }  -- Beng needs to eliminate annoying wrapping patterns like this.

data FileLocation = FileLocation {
	file :: FilePath,
	line :: Int,
	column :: Int }
