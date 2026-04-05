module Beng.Build.Context (
	Context(..),
	PrecedenceBound(..),
	empty,
	hasPrecedence,
	comparePrecedence,
	showPrecedence,
	push,
	concat,
	fromOps,
	fromThings,
	has
) where

import Prelude hiding (concat)

import Utils.Fallible hiding (fromMaybe)
import Utils.Lists (insertAt, showWithAnd, updateAt)
import Utils.Messaging (Messagable, debug, msg)

import qualified Beng.Operators as Ops
import Beng.Operators (Operator, SomeOperator(..))
import Beng.Operators.Declarations (isReturnTypeMismatch)
import {-# SOURCE #-} Beng.Things (propsOf)
import Beng.Types.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Types.Build.TypeTest (TypeTest(..))
import Beng.Types.Things (SomeThing)
import qualified Beng.Types.Operators.Declarations as Declaration

import Data.List (findIndex)
import Data.Maybe (fromMaybe, isJust)
import Data.Set (Set)
import qualified Data.Set as Set

-- private

{- This is private because it is useless aside from comparison.
   Precedence is not a static number in Beng like in most languages;
   ops can situate their precedence between two others ops with different precedents arbitrarily.
   So, the precedence list adds and loses items as the definitions stack pushes and pops.
   So, precedence's raw value means nothing except to compare two from the same context. -}
findPrecedenceWith :: (SomeOperator -> Bool) -> Context -> Maybe Int
findPrecedenceWith matches Context{..} = do
	opIndex <- findIndex matches deck
	let precedenceIndex = length deck - 1 - opIndex
	findIndex (precedenceIndex `Set.member`) precedence

findPrecedence :: Operator op => Context -> op -> Maybe Int
findPrecedence context op =
	findPrecedenceWith (\candidate -> candidate.decLoc == Ops.decLoc op) context

-- I wrote this tail recursion because Fallible.sequenceAny still runs _all_ Fallibles before
-- checking the results for any, causing every single operator to be checked even after a match is found.
hasIn :: Operator op => [SomeOperator] -> TypeTest -> op -> FallibleI Declaration.Mismatch ()
hasIn [] _ _ = Falue ()
hasIn [op] test requirement = (test, op) `Ops.satisfies` requirement
hasIn (op:rest) test requirement = case (test, op) `Ops.satisfies` requirement of
	{- If an operator satisfies the declaration's pattern, it will be the one called. So, even if another op deeper
		in the context stack can satisfy the declaration with pattern and return type, it doesn't matter: the
		one with the wrong return type will be called, so the declaration cannot be satisfied. -}
	Error e | isReturnTypeMismatch e -> Error e
	Error e1 -> case hasIn rest test requirement of
		Error e2 -> Error $ e1 <!> e2
		Falue _ -> Falue ()
	Falue _ -> Falue ()

-- instances

deriving instance Eq Context

instance Show Context where
	show context@Context{..} = concatMap showDec deck
		where
			showDec :: SomeOperator -> String
			showDec op = do
				let precedenceNote = case findPrecedence context op of
					Nothing -> ""
					Just precedence -> "P@" ++ show precedence ++ " "
				"\n\t" ++ precedenceNote ++ show op

instance Messagable Context where
	msg Context{..} = showWithAnd $ map msg deck

-- exported

empty :: Context
empty = Context { precedence = [], deck = [] }

hasPrecedence :: Operator op => Context -> op -> Bool
hasPrecedence context = isJust . findPrecedence context

comparePrecedence :: (Operator op1, Operator op2) => Context -> op1 -> op2 -> Maybe Ordering
comparePrecedence context a b = do
	aPredecence <- findPrecedence context a
	bPrecedence <- findPrecedence context b
	return $ compare aPredecence bPrecedence

showPrecedence :: Operator op => Context -> op -> Maybe String
showPrecedence context op = do
	precedence <- findPrecedence context op
	return $ [head $ show $ Ops.associativity op] ++ show precedence

push :: Operator op => op -> Context -> Context
push op context = do
	let someOp = SomeOperator op
	let forcePrecedence = \context comparative -> do
		let errorMessage = "The precedence of " ++ show comparative ++
			" was not available to push the precedence of " ++ show op ++ "!"
		fromMaybe (error errorMessage) $ findPrecedence context comparative

	let decIndex = length context.deck
	let updatePrec :: ([Set Int] -> [Set Int]) =
		case Ops.precedence op of
			Above minimum -> do
				let precIndex = forcePrecedence context minimum
				if precIndex == length context.precedence - 1
					then (++ [Set.singleton decIndex])
					else updateAt (precIndex + 1) (Set.insert decIndex)
			Below maximum -> do
				let precIndex = forcePrecedence context maximum
				if precIndex == 0
					then (Set.singleton decIndex:)
					else updateAt (precIndex - 1) (Set.insert decIndex)
			At sibling -> do
				let precIndex = forcePrecedence context sibling
				updateAt precIndex (Set.insert decIndex)
			Between bound1 bound2 -> do
				let precIndex1 = forcePrecedence context bound1
				let precIndex2 = forcePrecedence context bound2
				let precMax = max precIndex1 precIndex2
				let precMin = min precIndex1 precIndex2
				if precMax - precMin == 1 then
					insertAt precMin (Set.singleton decIndex)
				else do
					let precIndex = precMin + ((precMax - precMin) `div` 2)
					updateAt precIndex (Set.insert decIndex)
			Default -> -- TODO: improve this default in the future somehow.
				if null context.precedence
					then const [Set.singleton decIndex]
					else updateAt (length context.precedence - 1) (Set.insert decIndex)
			None -> id
	debug ("Pushing " ++ show op ++ " to context...") context{
		deck = someOp:context.deck,
		precedence = updatePrec context.precedence }

fromOps :: ([SomeOperator] -> Context)
fromOps = foldl (flip push) empty

concat :: [Context] -> Context
concat [] = empty
concat [c] = c
concat (c1:rest) = foldl (flip push) c1 $ concatMap deck rest

fromThings :: ([SomeThing] -> Context)
fromThings = fromOps . concatMap propsOf

has :: Operator op => TypeTest -> op -> FallibleI Declaration.Mismatch ()
-- TODO: don't let `hasIn` be called with an empty context or it will accept anything.
has test = hasIn test.context.deck test
