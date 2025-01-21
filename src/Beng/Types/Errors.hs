module Beng.Types.Errors (
	Error(..),
	ParseErrorDetails(..),
	Fallible,
	IOFallible
) where

import Utils.Fallible (FallibleI)
import Utils.Fallible.Trans (IOFallibleI)
import Utils.Populace (Populace)

import Beng.Types.Locations (FileLocation, Location)
import Beng.Types.Ops (Op)
import {-# SOURCE #-} Beng.Types.Ops.Declarations (Declaration)

data Error =
	-- TODO: callStack :: [(String, Location, Op)]
	UndefinedError {
		context :: String,
		declaration :: Declaration,
		caller :: Op,
		callLocation :: Location } |
	{- TypeError {
		context :: String,
		expected :: Type,
		considerations :: PatternComparator.Parses } | -}
	ParseError {
		details :: Populace ParseErrorDetails,
		fileLocation :: FileLocation }

data ParseErrorDetails =
	ParseErrorContext String (Populace ParseErrorDetails) |
	ParseErrorMessage String

type Fallible a = FallibleI Error a

type IOFallible a = IOFallibleI Error a