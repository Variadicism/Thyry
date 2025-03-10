module Beng.Types.Build.TypeTest (
	Contest(..),
	TypeTest(..),
	TypeTestResult
) where

import Utils.Fallible (FallibleI)

import Beng.Types.Build.Context (Context)
import Beng.Types.Things (Mismatch, Thing)

-- This is in its own file so that I can reuse the names "super" and "sub" despite
-- using them for Mismatch in Beng.Types.Things.
data Contest = Contest {
	super :: Thing,
	superName :: Maybe String,
	sub :: Thing,
	subName :: Maybe String }

data TypeTest = TypeTest {
	context :: Context,
	ongoing :: [Contest],  -- prevents infinite recursion
	current :: Contest }

type TypeTestResult = FallibleI Mismatch ()