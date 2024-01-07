module Beng.Parse.Types.Context (
	Context(..),
	PrecedenceBound(..)
) where

import Beng.Types.Declarations (Declaration)
import {-# SOURCE #-} Beng.Types.Definitions (Definition)

import Data.Set (Set)

data Context = Context {
{- Defintion end-indices grouped by precedence.
   Lower index -> lower/broader precedence
   The value is the index _from the end_ of the list of definitions.
       This is because new definitions are prepended, so the indexes shift,
       but indexes relative to the end of the list do not. -}
	precedence :: [Set Int],
{- Definitions stack
   Lower index -> defined later/closer (first dibs) -}
	definitions :: [Definition] }

data PrecedenceBound =
	Min |
	Max |
	Before Declaration |
	After Declaration |
	At Declaration