module Main where

import Prelude hiding ((<), (>))

import Utils.Testing

import Testing.Beng.Build.Code (testBuildCode)
import Testing.Beng.Build.NonPrefixed (testBuildNonPrefixed)
import Testing.Beng.Build.Prefixed (testBuildPrefixed)
import Testing.Beng.Build.Validate (testValidations)

-- test

main :: IO ()
main = test $ TestCategories "building" [
	testBuildCode,
	testBuildNonPrefixed,
	testBuildPrefixed,
	testValidations ]