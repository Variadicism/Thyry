module Beng.Errors (
	Error(..),
	Fallible,
	printError
) where

import Utils.Fallible hiding (Fallible)
import Utils.Lists (mapIndexed)
import Utils.Messaging (Messagable, TerminalColor(..), msg, tColor)
import Utils.Populace.Populace2 (Populace2)
import qualified Utils.Populace.Populace2 as P2

import Beng.Build.Cards ()
import Beng.Locations (Location)
import {-# SOURCE #-} Beng.Parse.Parsers ()
import Beng.Parse.Types.Parsers (State(..))
import Beng.Types.Errors
import qualified Beng.Types.Errors as Errors
import Beng.Types.Ops (Op(..))

import Data.List (intercalate)
import qualified Data.Text.Lazy as Text
import GHC.Records (HasField, getField)

-- private

showEqualErrorsUsing :: (Error -> String) -> Populace2 Error -> String
showEqualErrorsUsing toMessage errors =
	show (length errors) ++ " errors may equally apply:" ++
	foldl1 (++) (P2.map (('\n':) . toMessage) errors)

printErrorBody :: (Error -> String)
printErrorBody = \case
	EqualErrors{errors} -> do
		let printSubErrorBody index error =
			tColor [Red, Bold] (show index ++ ") ") ++
			printErrorBody error
		tColor [Red, Bold, Underlined] ("One of " ++ show (length errors) ++ " things went wrong:\n") ++
			intercalate "\n" (mapIndexed printSubErrorBody errors.l)
	ParseError{message} -> tColor [Red] message
	ue@UndefinedError{} -> tColor [Red] $ show ue

-- instances

instance Eq Error where
	(==) e1@EqualErrors{} e2@EqualErrors{} = e1.errors == e2.errors
	(==) p1@ParseError{} p2@ParseError{} =
		p1.message == p2.message &&
		p1.state.location == p2.state.location
	(==) u1@UndefinedError{} u2@UndefinedError{} = u1.op == u2.op
	(==) _ _ = False

instance Show Error where
	show = \case
		EqualErrors{errors} -> showEqualErrorsUsing show errors
		ParseError{message,state} -> show message ++ " at " ++ show state
		UndefinedError{context,op} ->
			context ++ show op.card.declaration ++ " cannot run before it is defined!"

instance Messagable Error where
	msg = \case
		EqualErrors{errors} -> showEqualErrorsUsing msg errors
		ParseError{message} -> show message
		e -> show e

instance Ord Error where
	-- Lower => closer to success
	compare e1 e2 = case (e1, e2) of
		-- Comparison targets are reversed because if >location, >success => lower Ordering
		(ParseError{state=state1}, ParseError{state=state2}) ->
			compare (Text.length state2.rest) (Text.length state1.rest)
		(UndefinedError{op=op1}, UndefinedError{op=op2}) ->
			compare op2.location op1.location
		(ParseError{}, UndefinedError{}) -> GT
		(UndefinedError{}, ParseError{}) -> LT
		(EqualErrors{errors=e1}, EqualErrors{errors=e2}) -> compare e1.head e2.head
		(EqualErrors{errors}, other) -> compare errors.head other
		(other, EqualErrors{errors}) -> compare other errors.head

instance IsError Error where
	prepend context = \case
		EqualErrors{errors} -> EqualErrors $ P2.map (prepend context) errors
		pe@ParseError{} -> pe{ message = context ++ pe.message }
		ue@UndefinedError{} -> ue{ Errors.context = context ++ ue.context }
	(<!>) e1 e2 = if compare e1 e2 /= EQ
		then max e1 e2
		else EqualErrors $ P2.dualton e1 e2

instance HasField "location" Error Location where
	getField = getLocation

-- exported

getLocation :: Error -> Location
getLocation = \case
	EqualErrors{errors} ->  -- Equal errors have the same Locations.
		getLocation $ P2.head errors
	ParseError{state} -> state.location
	UndefinedError{op} -> op.location

printError :: Error -> String
printError error =
	tColor [Reset, LightGray] (msg error.location ++ ",\n") ++
	printErrorBody error
	-- TODO: add the line of code with the error column highlighted