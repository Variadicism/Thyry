module Beng.Types.Build.Context (
	Context(..),
	PrecedenceBound(..)
) where

import {-# SOURCE #-} Beng.Types.Operators (SomeOperator)

import Data.Set (Set)

data Context = Context {
{- Defintion end-indices grouped by precedence.
   Lower index -> lower/broader precedence
   The value is the index _from the end_ of the list of definitions.
       This is because new definitions are prepended, so the indexes shift,
       but indexes relative to the end of the list do not. -}
	precedence :: [Set Int],
{- Declaration/definition stack of operators
   Lower index -> declared later/closer (first dibs) -}
	deck :: [SomeOperator] }

data PrecedenceBound =
	Above SomeOperator |
	Below SomeOperator |
	At SomeOperator |
	Between SomeOperator SomeOperator |
	Default |
	None
