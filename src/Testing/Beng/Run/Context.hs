module Testing.Beng.Run.Context (
	testRunContext
) where

import Utils.Testing

import qualified Testing.Beng.Utils.Build as Test
import Testing.Beng.Utils.Mocks (aValue, bValue, mockABCD)
import Testing.Beng.Utils.Run (assertEval)

import Beng.Parse.Types.Parsers (Parse(..))

build = Test.build mockABCD

-- tests

testRunContext :: TestCategory
testRunContext = TestCategories "running with context" [
	PureTests "static declaration" [
		("C := simple nullary", do
			result <- assert1 "result" =<< build "C := a \n C"
			assertEval aValue result.target),
		("C := addition", do
			result <- assert1 "result" =<< build "C := a+b \n C"
			assertEval (aValue + bValue) result.target),
		("C and D chained", do
			(cResult, addResult) <- assert2 "results" =<< build "C := a+b D := b/a C+D"
			assertEval (aValue + bValue) cResult.target
			assertEval (aValue + bValue + (bValue `div` aValue)) addResult.target)
		{- TODO: when we can resolve forward declarations, add this unit test.
		    - To make this work, D needs to be declared forward to parse its Scope, then defined
		       after the definition is complete.
			("D := recursive unused", do
			(dResult, addResult) <- assert2 "results" =<< build "C := b  D := C$D  D+b"
			assertEval bValue dResult.target
			-- Note: lazy evaluation avoids evaluating Right in `$`, so there is no infinite loop.
			assertEval (bValue + bValue) addResult.target)-}]]