module Beng.Build.Context (
	Context(..),
	PrecedenceBound(..),
	empty,
	hasPrecedence,
	comparePrecedence,
	showPrecedence,
	pushCard,
	pushDec,
	pushDef,
	concat,
	fromCards,
	fromThings,
	has
) where

import Prelude hiding (concat)

import Utils.Fallible hiding (fromMaybe)
import Utils.Lists (insertAt, showWithAnd, updateAt)
import Utils.Messaging (Messagable, debug, msg)

import Beng.Build.Cards (Card(..))
import Beng.Ops.Declarations (Declaration(..), isReturnTypeMismatch, satisfies)
import Beng.Ops.Definitions (Definition(..))
import {-# SOURCE #-} Beng.Things (cardsOf)
import Beng.Types.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Types.SatisfactionTest (SatisfactionTest(..))
import Beng.Types.Things (Thing)
import qualified Beng.Types.Ops.Declarations as Declaration

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
findPrecedenceWith :: (Card -> Bool) -> Context -> Maybe Int
findPrecedenceWith matches Context{..} = do
	cardIndex <- findIndex matches deck
	let precedenceIndex = length deck - 1 - cardIndex
	findIndex (precedenceIndex `Set.member`) precedence

findDecPrecedence :: Context -> Declaration -> Maybe Int
findDecPrecedence context dec =
	findPrecedenceWith (\c -> c.declaration == dec) context

findPrecedence :: Context -> Card -> Maybe Int
findPrecedence context card =
	findPrecedenceWith (==card) context

-- I wrote this tail recursion because Fallible.sequenceAny still runs _all_ Fallibles before
-- checking the results for any, causing every single card to be checked even after a match is found.
hasIn :: [Card] -> SatisfactionTest -> Declaration -> FallibleI Declaration.Mismatch ()
hasIn [] _ _ = Falue ()
hasIn [card] test dec = (test, card.declaration) `satisfies` dec
hasIn (card:rest) test dec = case (test, card.declaration) `satisfies` dec of
	{- If a card satisfies the declaration's pattern, it will be the one called. So, even if another card deeper
		in the context stack can satisfy the declaration with pattern and return type, it doesn't matter: the
		one with the wrong return type will be called, so the declaration cannot be satisfied. -}
	Error e | isReturnTypeMismatch e -> Error e
	Error e1 -> case hasIn rest test dec of
		Error e2 -> Error $ e1 <!> e2
		Falue _ -> Falue ()
	Falue _ -> Falue ()

-- instances

deriving instance Eq Context

instance Show Context where
	show context@Context{..} = concatMap showDec deck
		where
			showDec :: Card -> String
			showDec card = do
				let precedenceNote = case findPrecedence context card of
					Nothing -> ""
					Just precedence -> "P@" ++ show precedence ++ " "
				"\n\t" ++ precedenceNote ++ show card

instance Messagable Context where
	msg Context{..} = showWithAnd $ map msg deck

-- exported

empty :: Context
empty = Context { precedence = [], deck = [] }

hasPrecedence :: Context -> (Declaration -> Bool)
hasPrecedence context = isJust . findDecPrecedence context

comparePrecedence :: Context -> Card -> Card -> Maybe Ordering
comparePrecedence context a b = do
	aPredecence <- findPrecedence context a
	bPrecedence <- findPrecedence context b
	return $ compare aPredecence bPrecedence

showPrecedence :: Context -> Card -> Maybe String
showPrecedence context card = do
	precedence <- findPrecedence context card
	return $ [head (show card.declaration.associativity)] ++ show precedence

pushCard :: Card -> Context -> Context
pushCard card context = do
	let forcePrecedence :: Context -> Declaration -> Int = \context comparative -> do
		let errorMessage = "The precedence of " ++ show comparative ++
			" was not available to push the precedence of " ++ show card ++ "!"
		fromMaybe (error errorMessage) $ findDecPrecedence context comparative

	let decIndex = length context.deck
	let updatePrec :: ([Set Int] -> [Set Int]) =
		case card.declaration.precedence of
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
	debug ("Pushing " ++ show card ++ " to context...") context{
		deck = card:context.deck,
		precedence = updatePrec context.precedence }

pushDec :: Declaration -> (Context -> Context)
pushDec declaration = pushCard (DecCard declaration)

pushDef :: Definition -> (Context -> Context)
pushDef definition = pushCard (DefCard definition)

fromCards :: ([Card] -> Context)
fromCards = foldl (flip pushCard) empty

concat :: [Context] -> Context
concat [] = empty
concat [c] = c
concat (c1:rest) = foldl (flip pushCard) c1 $ concatMap deck rest

fromThings :: ([Thing] -> Context)
fromThings = fromCards . concatMap cardsOf

has :: SatisfactionTest -> (Declaration -> FallibleI Declaration.Mismatch ())
-- TODO: don't let `hasIn` be called with an empty context or it will accept anything.
has test = hasIn test.context.deck test