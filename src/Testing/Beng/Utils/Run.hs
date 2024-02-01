module Testing.Beng.Utils.Run (
	run,
	assertEval,
	assertUndefinedError
) where

import Utils.Fallible
import Utils.Messaging (msg)
import Utils.Testing

import qualified Beng.Run.Ops as Beng
import Beng.Run.Types.Data (Data)
import Beng.Types.Ops (Op)

-- exported

run :: Op -> Fallible Data
run = mapError msg . Beng.run

assertEval :: Data -> Op -> Fallible ()
assertEval expected op = do
	dataOut <- run op
	(expected, dataOut) `isEqualElse` ("Evaluation of " ++ show op ++ " didn't yield the expected result!")

assertUndefinedError :: Op -> Fallible ()
assertUndefinedError op = run op `hasErrorElse`
	"I expected an error when attempting to run an undefined declaration, but I didn't get one!"