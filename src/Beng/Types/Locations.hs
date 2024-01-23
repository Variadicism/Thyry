module Beng.Types.Locations (
	Location(..)
) where

data Location =
	Builtin { index :: Int } |
	Dynamic { file :: FilePath, line :: Int, column :: Int }