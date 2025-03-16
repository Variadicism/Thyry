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
-- import {-# SOURCE #-} Beng.Things ()
import Beng.Types.Parse.Parsers.Code (State(..))
import Beng.Types.Errors
import Beng.Types.Ops (Op(..))
import qualified Beng.Types.Errors as Error

import GHC.Records (HasField, getField)

-- private

printErrorBodyAt :: Int -> Error -> String
printErrorBodyAt indent error = replicate (2*indent) ' ' ++ case error of
	ParseError{..} -> details
	TypeError{..} -> msg cause
	ue@UndefinedError{} -> msg ue
	CompoundError{..} ->
		ifNotNull (++"\n") context ++
			intercalate "\n" (
				P.map ((replicate (2*indent) ' '++) . ("• "++) . printErrorBodyAt indent) compound)

-- instances

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
		UndefinedError{..} -> show declaration ++ " in " ++ show caller
		TypeError{..} -> "from " ++ argName ++ " in " ++ show caller ++ ": " ++ show cause
		CompoundError{..} -> ifNotNull (++", ") context ++ intercalate " AND " (P.map show compound)

instance Messagable Error where
	msg = \case
		ParseError{..} -> msg fileLocation ++ " " ++ msg details
		UndefinedError{..} -> msg declaration ++
			" in " ++ msg caller ++
			" cannot run before it is defined!"
		TypeError{..} -> "from " ++ argName ++ " in " ++ msg caller ++ ": " ++ msg cause
		CompoundError{..} -> ifNotNull (++", ") context ++ intercalate " AND " (P.map msg compound)

instance Ord Error where
	-- Lower => closer to success
	compare e1 e2 = case (e1, e2) of
		(e1@CompoundError{}, e2) -> compare e1.compound.head e2
		(e1, e2@CompoundError{}) -> compare e1 e2.compound.head
		(e1, e2) | typeIndex e1 == typeIndex e2 &&  e1.location == e2.location -> EQ
		(e1, e2) -> compare (typeIndex e1) (typeIndex e2)
		where typeIndex = \case
			UndefinedError{} -> 1
			TypeError{} -> 2
			ParseError{} -> 3
			CompoundError{} -> 4  -- impossible

instance IsError Error where
	prepend prefix = \case
		e@CompoundError{} -> e{ Error.context = prefix ++ e.context }
		e -> CompoundError { context = prefix, compound = P.singleton e }
	(<!>) e1 e2 = if compare e1 e2 == EQ
		then CompoundError { context = "", compound = P.Populace e1 [e2] }
		else min e1 e2  -- Lower => closer to success

instance HasField "location" Error Location where
	getField = getLocation

-- exported

parseError :: State -> String -> Error
parseError state message = ParseError {
	details = message,
	fileLocation = state.location }

{- typeError :: Thing -> PatternComparator.Parses -> Error
typeError expected parses = TypeError { context = "", expected, parses } -}

getLocation :: Error -> Location
getLocation = \case
	ParseError{fileLocation} -> Location.Code fileLocation
	UndefinedError{caller=Op{location}} -> location
	TypeError{caller} -> caller.location
	CompoundError{compound} -> compound.head.location

printError :: Error -> String
printError error =
	tColor [Reset, LightGray] (msg error.location ++ ",\n") ++
	tColor [Red] (printErrorBodyAt 0 error)
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