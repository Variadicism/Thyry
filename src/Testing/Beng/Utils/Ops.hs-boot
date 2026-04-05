module Testing.Beng.Utils.Ops where

import Utils.Fallible

import Beng.Types.Invocations (SomeInvocation)
import Beng.Types.Operators.Definitions (Definition)
import Beng.Types.Things (SomeThing)

import GHC.Records (HasField)

-- instances

instance HasField "op" (SomeInvocation -> Fallible a) (SomeThing -> Fallible a)

instance HasField "op" (i -> SomeInvocation -> Fallible a) (i -> SomeThing -> Fallible a)

instance HasField "op" (i -> j -> SomeInvocation -> Fallible a) (i -> j -> SomeThing -> Fallible a)

instance HasField "args" Definition ([(String, SomeThing -> Fallible ())] -> SomeInvocation -> Fallible ())

instance HasField "null" Definition (SomeInvocation -> Fallible ())

argAssertionsOf :: Definition -> [(String, SomeThing -> Fallible ())] -> SomeInvocation -> Fallible ()
