module Beng.Read.Types.Context (
	Context(..),
	comparePrecedence
) where

import Data.List (findIndex)
import Data.Maybe (fromJust)
import Data.Set (Set)
import qualified Data.Set as Set

import Beng.Types.Ops (OpDefinition)

-- types

data Context = Context {
{- Defintion end-indices grouped by precedence.
   Lower index -> lower/broader precedence
   The value is the index _from the end_ of the list of definitions.
       This is because new definitions are prepended, so the indexes shift,
       but indexes relative to the end of the list do not. -}
	precedence :: [Set Int],
{- Definitions stack
   Lower index -> defined later/closer (first dibs) -}
	definitions :: [OpDefinition] }  

-- private

{- This is private because it is useless aside from comparison.
   Precedence is not a static number in Beng like in most languages;
   ops can situate their precedence between two others ops with different precedents arbitrarily.
   So, the precedence list adds and loses items as the definitions stack pushes and pops.
   So, precedence's raw value means nothing except to compare two from the same context. -}
findPrecedence :: Context -> OpDefinition -> Int
findPrecedence Context{..} definition = do
	-- comparePrecedence _should_ only be used for defs in the context. :|
	let Just definitionIndex = findIndex (==definition) definitions
	let precedenceID = length definitions - 1 - definitionIndex
	-- This _should_ only be used for defs that require precedence. :|
	fromJust $ findIndex (precedenceID `Set.member`) precedence

-- exported

comparePrecedence :: Context -> OpDefinition -> OpDefinition -> Ordering
comparePrecedence context a b = compare (findPrecedence context a) $ findPrecedence context b