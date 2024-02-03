module Beng.Types.Errors (
	Error(..),
	Fallible,
	IOFallible
) where

import Utils.Fallible (FallibleI)
import Utils.Fallible.Trans (IOFallibleI)
import Utils.Populace (Populace)

import Beng.Build.Types.Cards (Card)
import Beng.Types.Ops (Op)

data Error =
	UndefinedError { context :: String, op :: Op } | -- TODO: callStack :: [(String, Location, Op)]
	-- TypeError { context :: String, expected :: Type, alternatives :: [Parse Op], state... } |
	ParseError {
		messages :: Populace (String, Maybe Card),
		file :: FilePath,
		line :: Int,
		column :: Int }

type Fallible a = FallibleI Error a

type IOFallible a = IOFallibleI Error a