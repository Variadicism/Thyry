module Beng.Types.Build.TypeTest (
	Contest(..),
	TypeTest(..),
	TypeTestResult
) where

import Utils.Fallible (FallibleI)

import Beng.Types.Build.Context (Context)
import Beng.Types.Things (Mismatch, Thing)

data Contest = Contest {
	candidate :: Thing,
	candidateName :: Maybe String,
	requirement :: Thing,
	requirementName :: Maybe String }

data TypeTest = TypeTest {
	context :: Context,
	ongoing :: [Contest],  -- prevents infinite recursion
	current :: Contest }

type TypeTestResult = FallibleI Mismatch ()
