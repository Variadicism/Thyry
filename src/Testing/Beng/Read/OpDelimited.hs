{-# LANGUAGE OverloadedStrings #-}

module Testing.Beng.Read.OpDelimited (
	testOpDelimited
) where

import Utils.Monads
import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpDelimited, OpLiteral))

testOpDelimited :: Void
testOpDelimited = do
	let readCommaPs = readAllMatches (OpDelimited "," (OpLiteral "p")) True

	readCommaPs "k" `isNullElse`
		"OpDelimited must parse nothing if its subgroup does not prefix the text."

	readCommaPs ",p,p" `isNullElse`
		"OpDelimited must parse nothing if its delimited prefixes the text and the subgroup cannot match an empty string."

	([("p", "")], readCommaPs "p") `isEqualElse`
		"OpDelimited must parse an instance of its subgroup first."

	([("p", "p")], readCommaPs "pp") `isEqualElse`
		"OpDelimited must parse only the first instance of its subgroup if the next instance is not preceded by the delimiter."

	([("p", ",pp"), ("p,p", "p")], readCommaPs "p,pp") `isEqualElse`
		"OpDelimited must parse multiple instances of its subgroup delimited by the given delimiter with each subgroup instances creating a new possible parsing."

	([("p", ",p,p"), ("p,p", ",p"), ("p,p,p", "")], readCommaPs "p,p,p") `isEqualElse`
		"OpDelimited must parse all instances -- even if more than 2 -- of its subgroup delimited right up to the end of the string."
