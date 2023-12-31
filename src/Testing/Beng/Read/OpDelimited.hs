module Testing.Beng.Read.OpDelimited (
	testOpDelimited
) where

import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpDelimited, OpLiteral))

testOpDelimited :: TestCategory
testOpDelimited = PureTests "OpDelimited" [
	("no read",
		readCommaPs "k" `isNullElse`
			"OpDelimited must read nothing if its subpattern does not prefix the text."),
	("no read while delimited",
		readCommaPs ",p,p" `isNullElse`
			"OpDelimited must read nothing if its delimited prefixes the text and the subpattern cannot match an empty string."),
	("read one subpattern",
		([("p", "")], readCommaPs "p") `isEqualElse`
			"OpDelimited must read an instance of its subpattern first."),
	("read one without delimiters",
		([("p", "p")], readCommaPs "pp") `isEqualElse`
			"OpDelimited must read only the first instance of its subgroup if the next instance is not preceded by the delimiter."),
	("read both options with 2 delimited subpatterns",
		([("p", ",pp"), ("p,p", "p")], readCommaPs "p,pp") `isEqualElse`
			"OpDelimited must read multiple instances of its subgroup delimited by the given delimiter with each subgroup instances creating a new possible parsing."),
	("read all options with 3+ delimited subpatterns",
		([("p", ",p,p"), ("p,p", ",p"), ("p,p,p", "")], readCommaPs "p,p,p") `isEqualElse`
			"OpDelimited must read all instances -- even if more than 2 -- of its subgroup delimited right up to the end of the string.") ]
	where readCommaPs = readAllMatches (OpDelimited (OpLiteral ",") (OpLiteral "p")) True