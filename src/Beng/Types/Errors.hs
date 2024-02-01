module Beng.Types.Errors (
	Error(..),
	Fallible,
	IOFallible
) where

import Utils.Fallible (FallibleI)
import Utils.Fallible.Trans (IOFallibleI)
import Utils.Populace.Populace2 (Populace2)

import {-# SOURCE #-} qualified Beng.Parse.Types.Parsers as Parser
import Beng.Types.Ops (Op)

data Error =
	EqualErrors { errors :: Populace2 Error } |
	UndefinedError { context :: String, op :: Op } | -- TODO: callStack :: [(String, Location, Op)]
	-- TypeError { context :: String, state :: Parser.State, expected :: Type, alternatives :: [Parse Op] } |
	ParseError { state :: Parser.State, message :: String }

type Fallible a = FallibleI Error a

type IOFallible a = IOFallibleI Error a