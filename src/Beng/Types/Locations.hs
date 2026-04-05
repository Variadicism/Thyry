module Beng.Types.Locations (
	FileLocation(..),
	Location(..)
) where

import {-# SOURCE #-} Beng.Types.Things (SomeThing)

data Location =
	Builtin { index :: Int } |
	BuiltinArg { name :: String, parentIndex :: Int } |
	BuiltinProp { propIndex :: Int, parentIndex :: Int, one :: SomeThing } |
	Code { fileLocation :: FileLocation }  -- Beng needs to eliminate annoying wrapping patterns like this.

data FileLocation = FileLocation {
	file :: FilePath,
	line :: Int,
	column :: Int }
