module Main where

import Utils.Testing

import Testing.Beng.EndToEnd.Code (makeCodeTests)

main :: IO ()
main = do
	codeTests <- makeCodeTests
	test $ TestCategories "end to end" [
		codeTests ]
