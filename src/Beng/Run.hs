module Beng.Run (
	run,
	runWhileOp
) where

import Beng.Operators (Operator(..))
import Beng.Invocations (SomeInvocation(..))
import Beng.Errors (Fallible)
import Beng.Types.Invocations (Invocation)
import Beng.Types.Things (SomeThing(..))

import Data.Typeable (cast)

run :: Operator op => Invocation op -> Fallible SomeThing
run = runUsing

runWhileOp :: SomeThing -> Fallible SomeThing
runWhileOp (SomeThing value) = case cast value of
	Just (SomeInvocation invocation) -> run invocation >>= runWhileOp
	Nothing -> return $ SomeThing value
