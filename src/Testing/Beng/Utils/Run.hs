module Testing.Beng.Utils.Run (
	assertEval,
	assertUndefinedError
) where

import Utils.Errors
import Utils.Testing

import qualified Beng.Run.Ops as Run
import Beng.Run.Types.Values (Data)
import Beng.Types.Ops (Op)

-- exported

assertEval :: Data -> Op -> Fallible ()
assertEval expected op = do
	dataOut <- Run.evaluate op
	(expected, dataOut) `isEqualElse` ("Evaluation of " ++ show op ++ " didn't yield the expected result!")

assertUndefinedError :: Op -> Fallible ()
assertUndefinedError op = Run.evaluate op `hasErrorElse`
	"I expected an error when attempting to run an undefined declaration, but I didn't get one!"