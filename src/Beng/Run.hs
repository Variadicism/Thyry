module Beng.Run (
	run,
	runWhileOp
) where

import Beng.Operators (Operator(..))
import Beng.Invocations (SomeInvocation(..))
import Beng.Errors (Fallible)
import Beng.Types.Invocations (Invocation)
import Beng.Types.Things (SomeThing(..), castThing)

run :: Operator op => Invocation op -> Fallible SomeThing
run = runUsing

runWhileOp :: SomeThing -> Fallible SomeThing
runWhileOp value = case castThing value of
	Just (SomeInvocation invocation) -> run invocation >>= runWhileOp
	Nothing -> return value
