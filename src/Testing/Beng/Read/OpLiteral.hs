{-# LANGUAGE OverloadedStrings #-}

module Testing.Beng.Read.OpLiteral (
	testOpLiteral
) where

import Utils.Monads
import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpLiteral))

testOpLiteral :: Void
testOpLiteral = do
	let readLit = \literal -> readAllMatches (OpLiteral literal) True

	readLit "l" "kl" `isNullElse`
		"OpLiteral must parse nothing if its literal does not prefix the text."

	([("l", "l")], readLit "l" "ll") `isEqualElse`
		"OpLiteral must parse exactly one instance of its literal."

	([("", "")], readLit "" "") `isEqualElse`
		"OpLiteral must be able to parse an empty string from any string, including empty."