{-# LANGUAGE OverloadedStrings #-}

module Testing.Beng.Read.OpOr (
	testOpOr
) where

import Utils.Monads
import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpLiteral, OpOr))

testOpOr :: Void
testOpOr = do
	let readAllOrs = \literals -> readAllMatches (OpOr (map OpLiteral literals)) False

	readAllOrs ["k"] "l" `isNullElse`
		"OpOr must parse nothing if its subgroup(s) do not prefix the text."

	([("k", "p")], readAllOrs ["k"] "kp") `isEqualElse`
		"OpOr must parse its only subgroup(s)."

	([("k", "k")], readAllOrs ["k"] "kk") `isEqualElse`
		"OpOr must parse only the first instance of its subgroup(s)."

	let readAllKsLsOrPs = readAllOrs ["k", "l", "p"]

	([("k", "n")], readAllKsLsOrPs "kn") `isEqualElse`
		"OpOr must parse its first subgroup."

	([("l", "n")], readAllKsLsOrPs "ln") `isEqualElse`
		"OpOr must parse its middle subgroup(s)."

	([("p", "n")], readAllKsLsOrPs "pn") `isEqualElse`
		"OpOr must parse its last subgroup."

	([("", "n")], readAllOrs [] "n") `isEqualElse`
		"OpOr must parse an empty string if given no subgroups."