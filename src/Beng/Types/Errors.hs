module Beng.Types.Errors (
	Error(..),
	ParseErrorDetails(..),
	Fallible,
	IOFallible
) where

import Utils.Fallible (FallibleI)
import Utils.Fallible.Trans (IOFallibleI)
import Utils.Populace (Populace)

import Beng.Types.Locations (FileLocation)
import Beng.Types.Ops (Op)

data Error =
	UndefinedError { context :: String, op :: Op } | -- TODO: callStack :: [(String, Location, Op)]
	-- TypeError { context :: String, expected :: Type, alternatives :: [Parse Op], state... } |
	ParseError {
		details :: Populace ParseErrorDetails,
		fileLocation :: FileLocation }

data ParseErrorDetails =
	ParseErrorContext String (Populace ParseErrorDetails) |
	ParseErrorMessage String

type Fallible a = FallibleI Error a

type IOFallible a = IOFallibleI Error a