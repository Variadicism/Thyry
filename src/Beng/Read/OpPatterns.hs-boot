module Beng.Read.OpPatterns where

import Utils.Readers (MultiReader)

import Beng.Types.OpPatterns (OpPattern)

import Data.Text.Lazy (Text)

readAllMatches :: OpPattern -> Bool -> MultiReader Text