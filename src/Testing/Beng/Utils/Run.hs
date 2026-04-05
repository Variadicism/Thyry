module Testing.Beng.Utils.Run (
	run,
	assertEval,
	assertUndefinedError
) where

import Utils.Fallible
import Utils.Messaging (msg)
import Utils.Testing

import Beng.Build.Context.Builders (asInt)
import Beng.Types.Invocations (SomeInvocation)
import qualified Beng.Run as Beng
import Beng.Types.Things (SomeThing)

-- exported

run :: SomeInvocation -> Fallible SomeThing
run = mapError msg . Beng.run

assertEval :: Int -> SomeInvocation -> Fallible ()
assertEval expected op = do
	value <- prependToError "An error occurred trying to test a run value: " $ run op
	int32 <- mapError msg $ asInt value
	(expected, fromIntegral int32) `isEqualElse` ("Evaluation of " ++ show op ++ " didn't yield the expected result!")

assertUndefinedError :: SomeInvocation -> Fallible ()
assertUndefinedError op = run op `hasErrorElse`
	"I expected an error when attempting to run an undefined declaration, but I didn't get one!"
