module Testing.Beng.Utils.Run (
	assertEval,
	assertUndefinedError
) where

import Utils.Fallible
import Utils.Testing

import Beng.Run.Ops as Run (run)
import Beng.Run.Types.Data (Data)
import Beng.Types.Ops (Op)

-- exported

assertEval :: Data -> Op -> Fallible ()
assertEval expected op = do
	dataOut <- run op
	(expected, dataOut) `isEqualElse` ("Evaluation of " ++ show op ++ " didn't yield the expected result!")

assertUndefinedError :: Op -> Fallible ()
assertUndefinedError op = run op `hasErrorElse`
	"I expected an error when attempting to run an undefined declaration, but I didn't get one!"