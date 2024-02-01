module Testing.Beng.Utils.Ops where

import Utils.Fallible

import Beng.Ops (Op)
import Beng.Parse.Types.Matches (Capture)
import Beng.Types.Ops.Definitions (Definition)

import GHC.Records (HasField)

-- instances

instance HasField "op" (Op -> Fallible a) (Capture -> Fallible a)

instance HasField "op" (i -> Op -> Fallible a) (i -> Capture -> Fallible a)

instance HasField "op" (i -> j -> Op -> Fallible a) (i -> j -> Capture -> Fallible a)

instance HasField "args" Definition ([(String, Capture -> Fallible ())] -> Op -> Fallible ())

instance HasField "null" Definition (Op -> Fallible ())

argAssertionsOf :: Definition -> [(String, Capture -> Fallible ())] -> Op -> Fallible ()