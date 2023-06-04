module Main where

import Utils.Errors (Error)
import Utils.Testing

import Testing.Beng.Read.OpEmpty (testOpEmpty)
import Testing.Beng.Read.OpLiteral (testOpLiteral)
import Testing.Beng.Read.OpSpace (testOpSpace)
import Testing.Beng.Read.OpOr (testOpOr)
import Testing.Beng.Read.OpAnd (testOpAnd)
import Testing.Beng.Read.OpDelimited (testOpDelimited)

main = do
	testOpEmpty
	testOpLiteral
	testOpSpace
	testOpOr
	testOpAnd
	testOpDelimited