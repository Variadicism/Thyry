module Testing.Beng.Read.OpLiteral (
	testOpLiteral
) where

import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpLiteral))

testOpLiteral :: TestCategory
testOpLiteral = PureTests "OpLiteral" [
	("read nothing",
		readLit "l" "kl" `isNullElse`
			"OpLiteral must read nothing if its literal does not prefix the text."),
	("read something",
		([("l", "l")], readLit "l" "ll") `isEqualElse`
			"OpLiteral must read exactly one instance of its literal."),
	("read empty",
		([("", "")], readLit "" "") `isEqualElse`
			"OpLiteral must be able to read an empty string from any string, including empty.") ]
	where readLit = \literal -> readAllMatches (OpLiteral literal) True