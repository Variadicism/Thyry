module Beng.Errors (
	Error(..),
	Fallible,
	parseError,
	getLocation,
	printError,
	compoundErrorsUsing,
	showCompoundErrorsUsing
) where

import Utils.Collective (intercalate)
import Utils.Fallible hiding (Fallible)
import Utils.Lists (ifNotNull)
import Utils.Messaging (Messagable, TerminalColor(..), msg, tColor)
import Utils.Populace (Populace)
import qualified Utils.Populace as P

import Beng.Locations (FileLocation(..), Location)
import qualified Beng.Locations as Location
import {-# SOURCE #-} Beng.Ops ()
import Beng.Ops.Declarations ()
import Beng.Types.Parse.Parsers.Code (State(..))
import Beng.Types.Errors
import qualified Beng.Types.Errors as Error

import GHC.Records (HasField, getField)

-- private

printParseErrorSubDetails :: Int -> Populace ParseErrorDetails -> String
printParseErrorSubDetails indent =
	intercalate "\n" . P.map ((replicate (2*indent) ' '++) . ("• "++) . printParseErrorDetail 0)

printParseErrorDetail :: Int -> ParseErrorDetails -> String
printParseErrorDetail indent = \case
	ParseErrorContext context subDetails ->
		context ++ "\n" ++ printParseErrorSubDetails (indent+1) subDetails
	ParseErrorMessage message -> message

printParseErrorDetails :: (Populace ParseErrorDetails -> String)
printParseErrorDetails details =
	tColor [Red] case details.tail of
		[] -> printParseErrorDetail 0 details.head
		_ -> printParseErrorSubDetails 0 details

printErrorBody :: (Error -> String)
printErrorBody = \case
	ParseError{details} -> printParseErrorDetails details
	ue@UndefinedError{} -> tColor [Red] $ msg ue

-- instances

deriving instance Eq ParseErrorDetails

instance Show ParseErrorDetails where
	show = show . \case
		ParseErrorContext context subDetails ->
			context ++ " " ++ case subDetails.tail of
				[] -> show subDetails.head
				_ -> show subDetails
		ParseErrorMessage message -> message

instance Eq Error where
	(==) p1@ParseError{} p2@ParseError{} =
		p1.details == p2.details &&
		p1.location == p2.location
	(==) u1@UndefinedError{} u2@UndefinedError{} =
		u1.declaration == u2.declaration &&
		u1.caller == u2.caller
	(==) _ _ = False

instance Show Error where
	show = \case
		ParseError{details,fileLocation=FileLocation{..}} ->
			concatMap (++":") [file, show line, show column] ++ " " ++ show details
		UndefinedError{..} -> ifNotNull (++" for ") context ++ show declaration ++
			" at " ++ show callLocation ++ " in " ++ show caller

instance Messagable Error where
	msg = \case
		ParseError{..} -> show fileLocation ++ " " ++ show details
		UndefinedError{..} -> context ++ show declaration ++ " in " ++ show caller ++ " cannot run before it is defined!"

instance Ord Error where
	-- Lower => closer to success
	compare e1 e2 = case (e1, e2) of
		(ParseError{}, UndefinedError{}) -> GT
		(UndefinedError{}, ParseError{}) -> LT
		_ ->  -- Operands are flipped because further location => closer to success => lower Ordering
			compare e2.location e1.location

instance IsError Error where
	prepend prefix = \case
		pe@ParseError{} -> pe{ details = P.singleton $ ParseErrorContext prefix pe.details }
		ue@UndefinedError{} ->
			-- I need to qualify the field... even in a record update... even with DuplicateRecordFields. >:(
			ue{ Error.context = prefix ++ ue.context }
	(<!>) e1 e2 = if compare e1 e2 /= EQ
		then min e1 e2
		else case e1 of
			ParseError{} -> do
				-- If compare e1 e2 == EQ, then e1 and e2 must be of matching types.
				let e2p@ParseError{} = e2
				e1{ details = e1.details <> e2p.details }
			UndefinedError{} -> do
				let e2u@UndefinedError{} = e2
				e1{ Error.context = e1.context ++ e2u.context }

instance HasField "location" Error Location where
	getField = getLocation

-- exported

parseError :: State -> String -> Error
parseError state message = ParseError {
	details = P.singleton $ ParseErrorMessage message,
	fileLocation = state.location }

{- typeError :: Type -> PatternComparator.Parses -> Error
typeError expected parses = TypeError { context = "", expected, parses } -}

getLocation :: Error -> Location
getLocation = \case
	ParseError{fileLocation} -> Location.Code fileLocation
	UndefinedError{callLocation} -> callLocation

printError :: Error -> String
printError error =
	tColor [Reset, LightGray] (msg error.location ++ ",\n") ++
	tColor [Red] (printErrorBody error)
	-- TODO: add the line of code with the error column highlighted

compoundErrorsUsing :: Ord e => (e -> Maybe (String, Populace e)) -> (String -> Populace e -> e) -> e -> e -> e
compoundErrorsUsing getCompound makeCompound e1 e2 = case compare e1 e2 of
	EQ -> case (getCompound e1, getCompound e2) of
		(Just (context1, compound1), Just (context2, compound2)) -> 
			makeCompound (context1 ++ " & " ++ context2) $
				P.Populace compound1.head $ compound1.tail ++ compound2.l
		_ -> -- Don't apply one compound's context to both; remember: it doesn't apply to the new error.
			makeCompound "" $ P.Populace e1 [e2]
	LT -> e1
	GT -> e2

showCompoundErrorsUsing :: (e -> String) -> String -> Populace e -> String
showCompoundErrorsUsing showE context compound =
	context ++ (case compound.tail of
		[] -> showE compound.head
		errors -> "there were " ++ show (length errors + 1) ++ " equally relevant errors:\n" ++
			intercalate "\n" (map showE compound.l))