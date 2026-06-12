module Beng.Types.Build.TypeTest (
	Binding(..),
	ParameterMatches,
	ParameterMatchResults(..),
	Contest(..),
	TypeTest(..),
	TypeTestProgressResult,
	TypeTestResult,
	matchesOf
) where

import Utils.Fallible (FallibleI)

import Beng.Types.Build.Context (Context)
import Beng.Types.Things (
	Binding(..),
	Mismatch,
	ParameterMatches,
	SomeParameterizedThing)

data Contest = Contest {
	candidate :: SomeParameterizedThing,
	candidateName :: Maybe String,
	requirement :: SomeParameterizedThing,
	requirementName :: Maybe String }

data TypeTest = TypeTest {
	context :: Context,
	ongoing :: [Contest],  -- prevents infinite recursion
	current :: Contest,
	candidateParameterMatches :: ParameterMatches,
	requirementParameterMatches :: ParameterMatches }

data ParameterMatchResults = ParameterMatchResults {
	candidateMatches :: ParameterMatches,
	requirementMatches :: ParameterMatches }

type TypeTestProgressResult = FallibleI Mismatch TypeTest

type TypeTestResult = FallibleI Mismatch ParameterMatchResults

matchesOf :: (TypeTest -> ParameterMatchResults)
matchesOf TypeTest{candidateParameterMatches, requirementParameterMatches} =
	ParameterMatchResults {
		candidateMatches = candidateParameterMatches,
		requirementMatches = requirementParameterMatches }
