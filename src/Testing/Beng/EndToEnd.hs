module Main where

import Utils.Testing

import Testing.Beng.EndToEnd.Code (testEndToEndCode)

main :: IO ()
main = test $ TestCategories "end to end" [
	testEndToEndCode ]
