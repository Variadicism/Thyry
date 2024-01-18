module Main where

import Utils.Testing

import Testing.Beng.Run.Context (testRunContext)
import Testing.Beng.Run.Evaluate (testRunEvaluate)

main = test $ TestCategories "run" [
	testRunContext,
	testRunEvaluate ]