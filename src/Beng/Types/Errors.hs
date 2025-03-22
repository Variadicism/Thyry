module Beng.Types.Errors (
	Error(..),
	Fallible,
	IOFallible
) where

import Utils.Fallible (FallibleI)
import Utils.Fallible.Trans (IOFallibleI)
import Utils.Populace (Populace)

import Beng.Types.Build.Cards (Card)
import Beng.Types.Locations (FileLocation)
import Beng.Types.Ops (Op)
import {-# SOURCE #-} Beng.Types.Ops.Declarations (Declaration)
import qualified Beng.Types.Things as Thing

data Error =
	-- \/ closest to success
	UndefinedError {
		-- TODO: callStack :: Populace (String, Location, Op)
		declaration :: Declaration,
		caller :: Op } |
	TypeError {
		-- TODO: callStack :: Populace (String, Location, Op)
		-- TODO: when Ops can continue parsing through type errors, make this an Op.
		attemptedCaller :: Card,
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