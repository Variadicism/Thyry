module Beng.Build.Cards (
	Card(..),
	Beng.Build.Cards.declaration,
	definition,
	isDefined,
	defineUsing,
	isDefinedUsing,
	filterDefs,
	filterDecs
) where

import Utils.Messaging (Messagable, msg)

import Beng.Locations (Location)
import Beng.Ops.Declarations (Declaration)
import Beng.Ops.Definitions (Definition)
import qualified Beng.Ops.Declarations as Declaration
import qualified Beng.Ops.Definitions as Definition
import Beng.Types.Build.Cards (Card(..))
import Beng.Types.Build.Context (Context(..))

import Data.List (find)
import Data.Maybe (catMaybes, isJust)
import GHC.Records (HasField, getField)

-- instances

instance HasField "declaration" Card Declaration where
	getField = Beng.Build.Cards.declaration

instance HasField "definition" Card (Maybe Definition) where
	getField = definition

instance HasField "location" Card Location where
	getField = location

deriving instance Eq Card

instance Show Card where
	show (DecCard dec) = show dec
	show (DefCard def) = show def

instance Messagable Card where
	msg (DecCard dec) = msg dec
	msg (DefCard def) = msg def

instance Ord Card where
	compare c1 c2 = compare c1.location c2.location

-- exported

declaration :: (Card -> Declaration)
declaration (DecCard dec) = dec
declaration (DefCard def) = def.declaration

definition :: (Card -> Maybe Definition)
definition (DecCard _) = Nothing
definition (DefCard def) = Just def

location :: (Card -> Location)
location (DecCard dec) = Declaration.location dec
location (DefCard def) = Definition.location def

isDefined :: (Card -> Bool)
isDefined = isJust . \c -> c.definition

defineUsing :: Context -> Card -> Maybe Definition
defineUsing _ (DefCard def) = Just def
defineUsing context (DecCard dec) = do
	cardFromContext <- find (\card -> card.declaration == dec) context.deck
	cardFromContext.definition

isDefinedUsing :: Context -> (Card -> Bool)
isDefinedUsing context = isJust . defineUsing context

filterDefs :: [Card] -> [Definition]
filterDefs = catMaybes . map definition

filterDecs :: [Card] -> [Declaration]
filterDecs = map yankDec . filter (not . isDefined)
	-- This partial function is safe because `not . isDefined` ensures that only DecCards come through.
	where yankDec = \(DecCard dec) -> dec