module Beng.Parse.Context (
	Context(..),
	PrecedenceBound(..),
	comparePrecedence,
	pushBetween,
	push
) where

import Data.List (findIndex)
import Data.Maybe (fromJust)
import qualified Data.Set as Set

import Beng.Ops.Definitions (Definition(..))
import Beng.Parse.Types.Context (Context(..), PrecedenceBound(..))

-- private

{- This is private because it is useless aside from comparison.
   Precedence is not a static number in Beng like in most languages;
   ops can situate their precedence between two others ops with different precedents arbitrarily.
   So, the precedence list adds and loses items as the definitions stack pushes and pops.
   So, precedence's raw value means nothing except to compare two from the same context. -}
findPrecedence :: Context -> Definition -> Int
findPrecedence Context{..} definition = do
	-- comparePrecedence _should_ only be used for defs in the context. :|
	let Just definitionIndex = findIndex (==definition) definitions
	let precedenceID = length definitions - 1 - definitionIndex
	-- This _should_ only be used for defs that require precedence. :|
	fromJust $ findIndex (precedenceID `Set.member`) precedence

-- exported

comparePrecedence :: Context -> Definition -> Definition -> Ordering
comparePrecedence context a b = compare (findPrecedence context a) $ findPrecedence context b

pushBetween :: PrecedenceBound -> PrecedenceBound -> Definition -> Context -> Context
-- TODO: insert based on PrecedenceBounds
pushBetween _ _ definition context = context{ definitions = definition:context.definitions }

push :: (Definition -> Context -> Context)
push = pushBetween Min Max