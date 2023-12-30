module Testing.Beng.Read.OpOr (
	testOpOr
) where

import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpLiteral, OpOr))

testOpOr :: TestCategory
testOpOr = PureTests "OpOr" [
	("read nothing",
		readAllOrs ["k"] "l" `isNullElse`
			"OpOr must read nothing if its subpattern(s) do not prefix the text."),
	("read with remainder",
		([("k", "p")], readAllOrs ["k"] "kp") `isEqualElse`
			"OpOr must read its only subpattern(s)."),
	("read one not repeats",
		([("k", "k")], readAllOrs ["k"] "kk") `isEqualElse`
			"OpOr must read only the first instance of its subpattern(s)."),
	("read first subpattern",
		([("k", "n")], readAllKsLsOrPs "kn") `isEqualElse`
			"OpOr must read its first subpattern."),
	("read middle subpattern",
		([("l", "n")], readAllKsLsOrPs "ln") `isEqualElse`
			"OpOr must read its middle subpattern(s)."),
	("read last subpattern",
		([("p", "n")], readAllKsLsOrPs "pn") `isEqualElse`
			"OpOr must read its last subpattern."),
	("read empty when empty",
		([("", "n")], readAllOrs [] "n") `isEqualElse`
			"OpOr must read an empty string if given no subpatterns.") ]
	where
		readAllOrs = \literals -> readAllMatches (OpOr (map OpLiteral literals)) False
		readAllKsLsOrPs = readAllOrs ["k", "l", "p"]
