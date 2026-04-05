module Beng.Types.Build.TypeTest (
	Contest(..),
	TypeTest(..),
	TypeTestResult
) where

import Utils.Fallible (FallibleI)

import Beng.Types.Build.Context (Context)
import Beng.Types.Things (Mismatch, SomeThing)

data Contest = Contest {
	candidate :: SomeThing,
	candidateName :: Maybe String,
	requirement :: SomeThing,
	requirementName :: Maybe String }

data TypeTest = TypeTest {
	context :: Context,
	ongoing :: [Contest],  -- prevents infinite recursion
	current :: Contest }

type TypeTestResult = FallibleI Mismatch ()
