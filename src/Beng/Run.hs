module Beng.Run (
	run,
	runWhileOp
) where

import Beng.Operators (Operator(..))
import Beng.Invocations (SomeInvocation(..))
import Beng.Errors (Fallible)
import Beng.Types.Things (SomeThing(..), castThing)

run :: SomeInvocation -> Fallible SomeThing
run (SomeInvocation invocation) = runUsing invocation

runWhileOp :: SomeThing -> Fallible SomeThing
runWhileOp value = case castThing value of
	Just invocation -> run invocation >>= runWhileOp
	Nothing -> return value
