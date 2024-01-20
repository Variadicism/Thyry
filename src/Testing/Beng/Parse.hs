module Main where

import Utils.Testing

import Testing.Beng.Parse.And (testAnd)
import Testing.Beng.Parse.CharClass (testCharClass)
import Testing.Beng.Parse.Delimited (testDelimited)
import Testing.Beng.Parse.Literal (testLiteral)
import Testing.Beng.Parse.Or (testOr)
import Testing.Beng.Parse.Space (testSpace)

main = test $ TestCategories "parsing Patterns" [
	testLiteral,
	testCharClass,
	testSpace,
	testOr,
	testAnd,
	testDelimited ]