module Main where

import Prelude hiding ((<), (>))

import Utils.Testing

import Testing.Beng.Build.Code (testBuildCode)
import Testing.Beng.Build.Ops (testBuildOp)

-- test

main :: IO ()
main = test $ TestCategories "building" [
	testBuildCode,
	testBuildOp]