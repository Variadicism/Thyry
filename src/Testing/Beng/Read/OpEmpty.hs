module Testing.Beng.Read.OpEmpty (
	testOpEmpty
) where

import Utils.Testing

import Beng.Read.OpPatterns (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(OpEmpty))

testOpEmpty :: TestCategory
testOpEmpty = PureTests "OpEmpty" [
	("read from something",
		(readAllMatches OpEmpty False "g", [("", "g")]) `isEqualElse`
			"OpEmpty should read nothing from the given input."),
	("read from nothing",
		(readAllMatches OpEmpty False "", [("", "")]) `isEqualElse`
			"OpEmpty should always read nothing and return the same text that it received, even if the input was empty.") ]