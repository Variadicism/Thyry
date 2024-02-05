module Beng.Errors (
	Error(..),
	Fallible,
	parseError,
	getLocation,
	printError
) where

import Utils.Collective (intercalate)
import Utils.Fallible hiding (Fallible)
import Utils.Lists (ifNotNull)
import Utils.Messaging (Messagable, TerminalColor(..), msg, tColor)
import qualified Utils.Populace as P
import Utils.Tuples (mapFst2)

import Beng.Build.Cards (declaration)
import Beng.Locations (FileLocation(..), Location)
import qualified Beng.Locations as Location
import {-# SOURCE #-} Beng.Parse.Parsers ()
import Beng.Parse.Types.Parsers (State(..))
import Beng.Types.Errors
import qualified Beng.Types.Errors as Error
import Beng.Types.Ops (Op(..))

import GHC.Records (HasField, getField)

-- private

printErrorBody :: (Error -> String)
printErrorBody = \case
	ParseError{messages} -> do
		let printMessageWithCard (message, card) = do
			-- The compiler complains if I use `card.declaration` here. >:(
			let clauseForCard = maybe "" \card -> "While parsing " ++ show (declaration card) ++ ", "
			tColor [Red] $ clauseForCard card ++ message
		case messages.tail of
			[] -> printMessageWithCard messages.head
			_ -> do
				let numberMessage index =
					(tColor [Red, Bold] (show (index+1) ++ ") ") ++) . tColor [Red]
				tColor [Red, Bold, Underlined]
						("One of " ++ show (length messages) ++ " things went wrong:\n") ++
					intercalate "\n" (P.mapIndexed numberMessage $ P.map fst messages)
	ue@UndefinedError{} -> tColor [Red] $ msg ue

-- instances

instance Eq Error where
	(==) p1@ParseError{} p2@ParseError{} =
		p1.messages == p2.messages &&
		p1.location == p2.location
	(==) u1@UndefinedError{} u2@UndefinedError{} = u1.op == u2.op
	(==) _ _ = False

instance Show Error where
	show = \case
		ParseError{messages,fileLocation=FileLocation{..}} ->
			concatMap (++":") [file, show line, show column] ++ " " ++ show messages
		UndefinedError{..} -> ifNotNull (++" for ") context ++ show op

instance Messagable Error where
	msg = \case
		ParseError{messages,fileLocation=FileLocation{..}} -> do
			let showMessageAndCard (message, card) =
				-- The compiler complains if I use `card.declaration` here. >:(
				show message ++ maybe "" ((" in "++) . show . declaration) card
			concatMap showMessageAndCard messages ++
				" at " ++ intercalate ":" [file, show line, show column]
		UndefinedError{..} -> context ++ show op.card.declaration ++ " cannot run before it is defined!"

instance Ord Error where
	-- Lower => closer to success
	compare e1 e2 = case (e1, e2) of
		(ParseError{}, UndefinedError{}) -> GT
		(UndefinedError{}, ParseError{}) -> LT
		_ ->  -- Operands are flipped because further location => closer to success => lower Ordering
			compare e2.location e1.location

instance IsError Error where
	prepend prefix = \case
		pe@ParseError{} -> pe{ messages = P.map (mapFst2 (prefix++)) pe.messages }
		ue@UndefinedError{} ->
			-- I need to qualify the field... even in a record update... even with DuplicateRecordFields. >:(
			ue{ Error.context = prefix ++ ue.context }
	(<!>) e1 e2 = if compare e1 e2 /= EQ
		then min e1 e2
		else case e1 of
			ParseError{} -> do
				-- If compare e1 e2 == EQ, then e1 and e2 must be of matching types.
				let e2p@ParseError{} = e2
				e1{ messages = e1.messages <> e2p.messages }
			UndefinedError{} -> do
				let e2u@UndefinedError{} = e2
				e1{ Error.context = e1.context ++ e2u.context }

instance HasField "location" Error Location where
	getField = getLocation

-- exported

parseError :: State -> String -> Error
parseError state message = ParseError {
	messages = P.singleton (message, state.parent),
	fileLocation = state.location }

getLocation :: Error -> Location
getLocation = \case
	ParseError{fileLocation} -> Location.Code fileLocation
	UndefinedError{op} -> op.location

printError :: Error -> String
printError error =
	tColor [Reset, LightGray] (msg error.location ++ ",\n") ++
	tColor [Red] (printErrorBody error)
	-- TODO: add the line of code with the error column highlighted