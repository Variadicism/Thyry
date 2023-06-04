{-# LANGUAGE OverloadedStrings #-}

module Testing.Beng.Read.OpAnd (
	testOpAnd
) where

import Utils.Monads
import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpAnd, OpLiteral))

testOpAnd :: Void
testOpAnd = do
	let readAllAnds = \literals -> readAllMatches (OpAnd (map OpLiteral literals)) False

	readAllAnds ["k"] "l" `isNullElse`
		"OpAnd must parse nothing if its subgroup(s) do not prefix the text."

	([("k", "p")], readAllAnds ["k"] "kp") `isEqualElse`
		"OpAnd must parse its only subgroup(s)."

	([("k", "k")], readAllAnds ["k"] "kk") `isEqualElse`
		"OpAnd must parse only the first instance of its subgroup(s)."

	([("klp", "n")], readAllAnds ["k", "l", "p"] "klpn") `isEqualElse`
		"OpAnd must parse all of its subgroups."

	([("", "n")], readAllAnds [] "n") `isEqualElse`
		"OpAnd must parse an empty string if given no subgroups."