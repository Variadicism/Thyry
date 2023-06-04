{-# LANGUAGE OverloadedStrings #-}

module Testing.Beng.Read.OpEmpty (
	testOpEmpty
) where

import Utils.Monads
import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpEmpty))

testOpEmpty :: Void
testOpEmpty = do
	(readAllMatches OpEmpty False "g", [("", "g")]) `isEqualElse`
		"OpEmpty should parse nothing from the given input."

	(readAllMatches OpEmpty False "", [("", "")]) `isEqualElse`
		"OpEmpty should always parse nothing and return the same text that it received, even if the input was empty."