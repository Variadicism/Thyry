module Beng.Types.Errors (
	Error(..),
	Fallible,
	IOFallible
) where

import Utils.Fallible (FallibleI)
import Utils.Fallible.Trans (IOFallibleI)
import Utils.Populace (Populace)

import {-# SOURCE #-} Beng.Types.Operators (SomeOperator)
import Beng.Types.Locations (FileLocation)
import {-# SOURCE #-} Beng.Types.Invocations (SomeInvocation)
import {-# SOURCE #-} qualified Beng.Types.Things as Thing

data Error =
	-- \/ closest to success
	UndefinedError {
		-- TODO: callStack :: Populace (String, Location, Op)
		caller :: SomeInvocation } |
	TypeError {
		-- TODO: callStack :: Populace (String, Location, Op)
		-- TODO: when Ops can continue parsing through type errors, make this an Op.
		attemptedCaller :: SomeOperator,
		argName :: String,
		-- TODO: mismatchedOp :: Op,
		fileLocation :: FileLocation,
		cause :: Thing.Mismatch } |
	ParseError {
		fileLocation :: FileLocation,
		details :: String } |  -- TODO: structure this string
	-- /\ furthest from success
	CompoundError { contexts :: [String], compound :: Populace Error }

type Fallible a = FallibleI Error a

type IOFallible a = IOFallibleI Error a
