module Beng.Build.Types.Context (
	Context(..),
	PrecedenceBound(..)
) where

import Beng.Build.Types.Cards (Card)
import {-# SOURCE #-} Beng.Types.Ops.Declarations (Declaration)

import Data.Set (Set)

data Context = Context {
{- Defintion end-indices grouped by precedence.
   Lower index -> lower/broader precedence
   The value is the index _from the end_ of the list of definitions.
       This is because new definitions are prepended, so the indexes shift,
       but indexes relative to the end of the list do not. -}
	precedence :: [Set Int],
{- Declaration/definition stack of "cards"
   Lower index -> declared later/closer (first dibs) -}
	deck :: [Card] }

data PrecedenceBound =
	Above Declaration |
	Below Declaration |
	At Declaration |
	Between Declaration Declaration |
	Default |
	None