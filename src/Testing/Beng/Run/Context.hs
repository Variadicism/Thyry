module Testing.Beng.Run.Context (
	testRunContext
) where

import Utils.Testing

import qualified Testing.Beng.Utils.Build as Test
import Testing.Beng.Utils.Mocks (aValue, bValue, mockABMathScopedCD)
import Testing.Beng.Utils.Run (assertEval)

import Beng.Parse.Types.Parsers (Result(..))

build = Test.build mockABMathScopedCD

-- tests

testRunContext :: TestCategory
testRunContext = TestCategories "running with context" [
	PureTests "static declaration" [
		("C := simple nullary", do
			result <- assert1 "result" $ build "C := a \n C"
			assertEval aValue result.target),
		("C := addition", do
			result <- assert1 "result" $ build "C := a+b \n C"
			assertEval (aValue + bValue) result.target),
		("C and D chained", do
			(cResult, addResult) <- assert2 "results" $ build "C := a+b D := b/a C+D"
			assertEval (aValue + bValue) cResult.target
			assertEval (aValue + bValue + (bValue `div` aValue)) addResult.target)]
		{- TODO: test using the op itself in the Value evaluation
		   This cannot be tested while everything is evaluated to Data because it can only
		   result in infinite loops, but when Ops can be values, this will be useful and testable.
		   This also requires mechanics to insert definitions into declarations later. -}]