module Testing.Beng.Utils.Ops where

import Utils.Fallible

import Beng.Ops (Op)
import Beng.Types.Ops.Definitions (Definition)
import Beng.Types.Values (Value)

import GHC.Records (HasField)

-- instances

instance HasField "op" (Op -> Fallible a) (Value -> Fallible a)

instance HasField "op" (i -> Op -> Fallible a) (i -> Value -> Fallible a)

instance HasField "op" (i -> j -> Op -> Fallible a) (i -> j -> Value -> Fallible a)

instance HasField "args" Definition ([(String, Value -> Fallible ())] -> Op -> Fallible ())

instance HasField "null" Definition (Op -> Fallible ())

argAssertionsOf :: Definition -> [(String, Value -> Fallible ())] -> Op -> Fallible ()