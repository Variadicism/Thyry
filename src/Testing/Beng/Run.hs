module Main where

import Utils.Testing

import Testing.Beng.Run.Context (testRunContext)
import Testing.Beng.Run.Ops (testRunOps)

main = test $ TestCategories "run" [
	testRunContext,
	testRunOps ]