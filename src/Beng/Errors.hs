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
import Utils.Lists (equalsIgnoreOrder, ifNotNull)
import Utils.Messaging (Messagable, TerminalColor(..), msg, tColor)
import Utils.Populace (Populace)
import qualified Utils.Populace as P

import Beng.Operators ()
import Beng.Locations (FileLocation(..), Location)
import qualified Beng.Locations as Location
import {-# SOURCE #-} Beng.Invocations ()
import Beng.Operators.Declarations ()
import Beng.Types.Parse.Parsers.Code (State(..))
import Beng.Types.Errors
import Beng.Types.Invocations (SomeInvocation(..), Invocation(..))
import qualified Beng.Types.Errors as Error

import Data.List (nub)
import GHC.Records (HasField, getField)

-- private

printErrorBodyAt :: Int -> (Error -> String)
printErrorBodyAt indentLevel = \case
	ParseError{..} -> details
	TypeError{..} ->
		"in '" ++ argName ++ "' of " ++ msg attemptedCaller.pattern ++ ",\n" ++
			indentFor (indentLevel+1) ++ msg cause
	ue@UndefinedError{} -> msg ue
	CompoundError{..} -> do
		-- Like the errors above, this compound error must not indent its first line.
		-- But, it should indent subsequent lines.
		let printEqualEntries indentLevel indentFirst entries = do
			let printEntry index entry = do
				let prefix = if index == 0 && indentFirst
					then indentFor indentLevel ++ "• "
					else if index == 0 then "• "
					else indentFor indentLevel ++ "\n& "
				prefix ++ entry
			concat $ P.mapIndexed printEntry entries
		let printSubErrors indentLevel indentFirst =
			printEqualEntries indentLevel indentFirst . P.map (printErrorBodyAt indentLevel)
		case contexts of
			[] -> printSubErrors indentLevel False compound
			[context] ->
				context ++ "\n" ++ printSubErrors (indentLevel+1) True compound
			first:rest -> do
				let contextsHeader = printEqualEntries indentLevel False $ P.Populace first rest
				contextsHeader ++ "\n" ++ printSubErrors (indentLevel+1) True compound
	where
		indentFor indentLevel = replicate (4*indentLevel) ' '

-- instances

instance Eq Error where
	(==) p1@ParseError{} p2@ParseError{} =
		p1.details == p2.details &&
		p1.location == p2.location
	(==) u1@UndefinedError{} u2@UndefinedError{} =
		u1.caller == u2.caller
	(==) c1@CompoundError{} c2@CompoundError{} =
		c1.contexts == c2.contexts &&
		c1.compound == c2.compound
	(==) _ _ = False

instance Show Error where
	show = \case
		ParseError{details,fileLocation=FileLocation{..}} ->
			concatMap (++":") [file, show line, show column] ++ " " ++ show details
		UndefinedError{caller=SomeInvocation invocation} ->
			show invocation.operator ++ " in " ++ show invocation
		TypeError{..} -> "at " ++ show fileLocation ++
			" for " ++ argName ++
			" in " ++ show attemptedCaller ++ ": " ++
			show cause
		CompoundError{..} -> ifNotNull (++", ") (intercalate " AND " contexts) ++
			intercalate " AND " (P.map show compound)

instance Messagable Error where
	msg = \case
		ParseError{..} -> msg fileLocation ++ " " ++ msg details
		UndefinedError{caller=SomeInvocation invocation} -> msg invocation.operator ++
			" in " ++ msg invocation ++
			" cannot run before it is defined!"
		TypeError{..} -> "at " ++ msg fileLocation ++
			" for " ++ argName ++
			" in " ++ msg attemptedCaller ++ ": " ++
			msg cause
		CompoundError{..} -> ifNotNull (++", ") (intercalate " AND " contexts) ++
			intercalate " AND " (P.map msg compound)

instance Ord Error where
	-- Lower => closer to success
	compare e1 e2 = case (e1, e2) of
		(e1@CompoundError{}, e2) -> compare e1.compound.head e2
		(e1, e2@CompoundError{}) -> compare e1 e2.compound.head
		(e1, e2) ->
			compare (typeIndex e1) (typeIndex e2) <>
			-- Swap operands because later location are closer to success (ordered lower).
			compare e2.location e1.location
		where typeIndex = \case
			UndefinedError{} -> 1
			TypeError{} -> 2
			ParseError{} -> 3
			CompoundError{} -> 4  -- impossible

instance IsError Error where
	prepend prefix = \case
		e@CompoundError{} -> e{ Error.contexts = case e.contexts of
			[] -> [prefix]
			contexts -> map (prefix++) contexts }
		e -> CompoundError { contexts = [prefix], compound = P.singleton e }
	(<!>) e1 e2 = if compare e1 e2 == EQ
		then case (e1, e2) of
			(e1@CompoundError{}, e2@CompoundError{}) | e1.compound `equalsIgnoreOrder` e2.compound ->
				CompoundError (nub $ e1.contexts <> e2.contexts) e1.compound
			(e1@CompoundError{}, e2@CompoundError{}) | e1.contexts `equalsIgnoreOrder` e2.contexts ->
				CompoundError e1.contexts $ e1.compound <> e2.compound
			(e1@CompoundError{}, e2) | null e1.contexts ->
				CompoundError [] $ P.snoc e1.compound e2
			(e1, e2@CompoundError{}) | null e2.contexts ->
				CompoundError [] $ P.cons e1 e2.compound
			(e1, e2) ->
				CompoundError [] $ P.Populace e1 [e2]
		else min e1 e2  -- lower -> closer to success

instance HasField "location" Error Location where
	getField = getLocation

-- exported

parseError :: State -> String -> Error
parseError state message = ParseError {
	details = message,
	fileLocation = state.location }

getLocation :: Error -> Location
getLocation = \case
	ParseError{fileLocation} -> Location.Code fileLocation
	UndefinedError{caller=SomeInvocation invocation} -> invocation.location
	TypeError{fileLocation} -> Location.Code fileLocation
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
		_ -> makeCompound "" $ P.Populace e1 [e2]
	LT -> e1
	GT -> e2

showCompoundErrorsUsing :: (e -> String) -> String -> Populace e -> String
showCompoundErrorsUsing showE context compound =
	context ++ (case compound.tail of
		[] -> showE compound.head
		errors -> "there were " ++ show (length errors + 1) ++ " equally relevant errors:\n" ++
			intercalate "\n" (map showE compound.l))
