module Testing.Beng.Utils.Ops where

import Utils.Fallible

import Beng.Types.Invocations (SomeInvocation)
import Beng.Types.Operators.Definitions (Definition)
import Beng.Types.Things (Thing)

import GHC.Records (HasField)

-- instances

instance HasField "op" (SomeInvocation -> Fallible a) (Thing -> Fallible a)

instance HasField "op" (i -> SomeInvocation -> Fallible a) (i -> Thing -> Fallible a)

instance HasField "op" (i -> j -> SomeInvocation -> Fallible a) (i -> j -> Thing -> Fallible a)

instance HasField "args" Definition ([(String, Thing -> Fallible ())] -> SomeInvocation -> Fallible ())

instance HasField "null" Definition (SomeInvocation -> Fallible ())

argAssertionsOf :: Definition -> [(String, Thing -> Fallible ())] -> SomeInvocation -> Fallible ()
