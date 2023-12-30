module Testing.Beng.Read.OpAnd (
	testOpAnd
) where

import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpAnd, OpLiteral))

testOpAnd :: TestCategory
testOpAnd = PureTests "OpAnd" [
	("no read",
		readAllAnds ["k"] "l" `isNullElse`
			"OpAnd must read nothing if its subpattern(s) do not prefix the text."),
	("one subpattern",
		([("k", "p")], readAllAnds ["k"] "kp") `isEqualElse`
			"OpAnd must read its only subpattern(s)."),
	("no repeats",
		([("k", "k")], readAllAnds ["k"] "kk") `isEqualElse`
			"OpAnd must read only the first instance of its subpattern(s)."),
	("multiple subpatterns",
		([("klp", "n")], readAllAnds ["k", "l", "p"] "klpn") `isEqualElse`
			"OpAnd must read all of its subpatterns."),
	("no subpatterns",
		([("", "n")], readAllAnds [] "n") `isEqualElse`
			"OpAnd must read an empty string if given no subpatterns.") ]
	where readAllAnds = \literals -> readAllMatches (OpAnd (map OpLiteral literals)) False
