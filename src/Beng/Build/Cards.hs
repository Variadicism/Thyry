module Beng.Build.Cards (
	Card(..),
	Beng.Build.Cards.declaration,
	definition,
	isDefined,
	defineUsing,
	isDefinedUsing
) where

import Utils.Messaging (Messagable, msg)

import Beng.Build.Types.Cards (Card(..))
import Beng.Build.Types.Context (Context(..))
import Beng.Ops.Declarations (Declaration)
import Beng.Ops.Definitions (Definition(..))

import Data.List (find)
import Data.Maybe (isJust)
import GHC.Records (HasField, getField)

-- instances

instance HasField "declaration" Card Declaration where
	getField = Beng.Build.Cards.declaration

instance HasField "definition" Card (Maybe Definition) where
	getField = definition

deriving instance Eq Card

instance Show Card where
	show (DecCard dec) = show dec
	show (DefCard def) = show def

instance Messagable Card where
	msg card = msg card.declaration

-- exported

declaration :: (Card -> Declaration)
declaration (DecCard dec) = dec
declaration (DefCard def) = def.declaration

definition :: (Card -> Maybe Definition)
definition (DecCard _) = Nothing
definition (DefCard def) = Just def

isDefined :: (Card -> Bool)
isDefined = isJust . \c -> c.definition

defineUsing :: Context -> Card -> Maybe Definition
defineUsing _ (DefCard def) = Just def
defineUsing context (DecCard dec) = do
	cardFromContext <- find (\card -> card.declaration == dec) context.deck
	cardFromContext.definition

isDefinedUsing :: Context -> (Card -> Bool)
isDefinedUsing context = isJust . defineUsing context
