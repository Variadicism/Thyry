{-# LANGUAGE OverloadedStrings #-}

module Main where

import Utils.Errors (Error)
import Utils.Testing

import Beng.Read.OpPatterns (OpPattern(..), readAllMatches)

isNullElse :: (Show a, Eq a) => [a] -> (Error -> IO ())
isNullElse list = (([], list) `isEqualElse`)

main = do
	-- OpEmpty
	(readAllMatches OpEmpty False "", [("", "")]) `isEqualElse` "OpEmpty should always parse nothing and return the same text that it received, even if the input was empty."

	-- OpSpace
	readAllMatches OpSpace False "+" `isNullElse` "OpSpace must parse nothing if there is no space or word boundary."
	readAllMatches OpSpace True "239" `isNullElse` "OpSpace must understand that if an alphanumeric begins the text to parse and precedes the text to parse, there is no word boundary."
	([(" ", "90")], readAllMatches OpSpace False " 90") `isEqualElse` "OpSpace must parse a space."
	([("", " 90"), (" ", "90")], readAllMatches OpSpace True " 90") `isEqualElse` "OpSpace must parse both a word boundary and a space option if both are possible (with the word boundary coming as the first, non-greedy option)."
	([("", "  18"), (" ", " 18"), ("  ", "18")], readAllMatches OpSpace True "  18") `isEqualElse` "OpSpace must parse all possible space options as well as the word boundary option."

	-- OpLiteral
	let readLit = \literal -> readAllMatches (OpLiteral literal) True
	readLit "l" "kl" `isNullElse` "OpLiteral must parse nothing if its literal does not prefix the text."
	([("l", "l")], readLit "l" "ll") `isEqualElse` "OpLiteral must parse exactly one instance of its literal."
	([("", "")], readLit "" "") `isEqualElse` "OpLiteral must be able to parse an empty string from any string, including empty."

	-- OpAnd; WARNING: uses OpLiteral for testing because it has to have subgroups
	let readAllAnds = \literals -> readAllMatches (OpAnd (map OpLiteral literals)) False
	readAllAnds ["k"] "l" `isNullElse` "OpAnd must parse nothing if its subgroup(s) do not prefix the text."
	([("k", "p")], readAllAnds ["k"] "kp") `isEqualElse` "OpAnd must parse its subgroup(s)."
	([("k", "k")], readAllAnds ["k"] "kk") `isEqualElse` "OpAnd must parse only the first instance of its subgroup(s)."
	([("klp", "n")], readAllAnds ["k", "l", "p"] "klpn") `isEqualElse` "OpAnd must parse all of its subgroups."
	([("", "")], readAllAnds [] "") `isEqualElse` "OpAnd must parse an empty string if given no subgroups."

	-- OpDelimited; WARNING: uses OpLiteral for testing because it has to have subgroups
	let readCommaPs = readAllMatches (OpDelimited "," (OpLiteral "p")) True
	readCommaPs "k" `isNullElse` "OpDelimited must parse nothing if its subgroup does not prefix the text."
	readCommaPs ",p,p" `isNullElse` "OpDelimited must parse nothing if its delimited prefixes the text and the subgroup cannot match an empty string."
	([("p", "")], readCommaPs "p") `isEqualElse` "OpDelimited must parse an instance of its subgroup first."
	([("p", "p")], readCommaPs "pp") `isEqualElse` "OpDelimited must parse only the first instance of its subgroup if the next instance is not preceded by the delimiter."
	([("p", ",pp"), ("p,p", "p")], readCommaPs "p,pp") `isEqualElse` "OpDelimited must parse multiple instances of its subgroup delimited by the given delimiter with each subgroup instances creating a new possible parsing."
	([("p", ",p,p"), ("p,p", ",p"), ("p,p,p", "")], readCommaPs "p,p,p") `isEqualElse` "OpDelimited must parse all instances -- even if more than 2 -- of its subgroup delimited right up to the end of the string."
