{-# LANGUAGE OverloadedStrings #-}

module Testing.Beng.Read.OpSpace (
	testOpSpace
) where

import Utils.Monads
import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpSpace))

testOpSpace :: Void
testOpSpace = do
	readAllMatches OpSpace False "+" `isNullElse`
		"OpSpace must parse nothing if there is no space or word boundary."

	readAllMatches OpSpace True "239" `isNullElse`
		"OpSpace must understand that if an alphanumeric begins the text to parse and precedes the text to parse, there is no word boundary."

	([(" ", "90")], readAllMatches OpSpace False " 90") `isEqualElse`
		"OpSpace must parse a space."

	([("", " 90"), (" ", "90")], readAllMatches OpSpace True " 90") `isEqualElse`
		"OpSpace must parse both a word boundary and a space option if both are possible (with the word boundary coming as the first, non-greedy option)."

	([("", "  18"), (" ", " 18"), ("  ", "18")], readAllMatches OpSpace True "  18") `isEqualElse`
		"OpSpace must parse all possible space options as well as the word boundary option."