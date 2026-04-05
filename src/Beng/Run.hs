module Beng.Run (
	run,
	runWhileOp
) where

import Beng.Operators (Operator(..))
import Beng.Invocations (SomeInvocation(..))
import Beng.Errors (Fallible)
import Beng.Types.Things (Thing(InvValue))

run :: SomeInvocation -> Fallible Thing
run (SomeInvocation invocation) = runUsing invocation

runWhileOp :: Thing -> Fallible Thing
runWhileOp = \case
	InvValue invocation -> run invocation >>= runWhileOp
	value -> return value
