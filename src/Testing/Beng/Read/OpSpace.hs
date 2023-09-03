{-# LANGUAGE OverloadedStrings #-}

module Testing.Beng.Read.OpSpace (
	testOpSpace
) where

import Utils.Monads
import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpSpace))

testOpSpace :: TestCategory
testOpSpace = PureTests "OpSpace" [
	("no read",
		readAllMatches OpSpace False "+" `isNullElse`
			"OpSpace must read nothing if there is no space or word boundary."),
	("no word boundary",
		readAllMatches OpSpace True "239" `isNullElse`
			"OpSpace must understand that if an alphanumeric begins the text to read and precedes the text to parse, there is no word boundary."),
	("read space without word char",
		([(" ", "90")], readAllMatches OpSpace False " 90") `isEqualElse`
			"OpSpace must read a space."),
	("read empty and space with word char",
		([("", " 90"), (" ", "90")], readAllMatches OpSpace True " 90") `isEqualElse`
			"OpSpace must read both a word boundary and a space option if both are possible (with the word boundary coming as the first, non-greedy option)."),
	("read empty and different space counts",
		([("", "  18"), (" ", " 18"), ("  ", "18")], readAllMatches OpSpace True "  18") `isEqualElse`
			"OpSpace must read all possible space options as well as the word boundary option.") ]