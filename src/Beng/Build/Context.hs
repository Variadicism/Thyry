module Beng.Build.Context (
	Context(..),
	PrecedenceBound(..),
	hasPrecedence,
	comparePrecedence,
	showPrecedence,
	pushBetween,
	push
) where

import Beng.Ops.Declarations (Declaration(..))
import Beng.Ops.Definitions (Definition(..))
import Beng.Build.Types.Context (Context(..), PrecedenceBound(..))

import Data.List (findIndex, intercalate)
import Data.Maybe (isJust)
import qualified Data.Set as Set

-- private

{- This is private because it is useless aside from comparison.
   Precedence is not a static number in Beng like in most languages;
   ops can situate their precedence between two others ops with different precedents arbitrarily.
   So, the precedence list adds and loses items as the definitions stack pushes and pops.
   So, precedence's raw value means nothing except to compare two from the same context. -}
findPrecedence :: Context -> Declaration -> Maybe Int
findPrecedence Context{..} target = do
	-- comparePrecedence _should_ only be used for defs in the context. :|
	let Just definitionIndex = findIndex ((==target) . declaration) definitions
	let precedenceIndex = length definitions - 1 - definitionIndex
	findIndex (precedenceIndex `Set.member`) precedence

-- instances

instance Show Context where
	show context@Context{..} = intercalate ", " $ map showDef definitions
		where
			showDef :: Definition -> String
			showDef definition = do
				let precedenceNote = case findPrecedence context definition.declaration of
					Nothing -> ""
					Just precedence -> "P@" ++ show precedence ++ " "
				precedenceNote ++ show definition

-- exported

hasPrecedence :: Context -> (Declaration -> Bool)
hasPrecedence context = isJust . findPrecedence context

comparePrecedence :: Context -> Declaration -> Declaration -> Maybe Ordering
comparePrecedence context a b = do
	aPredecence <- findPrecedence context a
	bPrecedence <- findPrecedence context b
	return $ compare aPredecence bPrecedence

showPrecedence :: Context -> Declaration -> Maybe String
showPrecedence context declaration = do
	precedence <- findPrecedence context declaration
	return $ [head (show declaration.associativity)] ++ show precedence

-- TODO: allow the insertion of Declarations, not just Definitions
pushBetween :: PrecedenceBound -> PrecedenceBound -> Definition -> Context -> Context
-- TODO: insert based on PrecedenceBounds
pushBetween _ _ definition context = context{ definitions = definition:context.definitions }

push :: (Definition -> Context -> Context)
push = pushBetween Min Max