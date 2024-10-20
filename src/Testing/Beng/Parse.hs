module Main where

import Utils.Testing

import Testing.Beng.Parse.Code (testCode)

main = test $ TestCategories "parsing code" [
	testCode ]