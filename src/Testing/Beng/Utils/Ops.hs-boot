module Testing.Beng.Utils.Ops where

import Utils.Fallible

import Beng.Ops (Op)
import Beng.Types.Ops.Definitions (Definition)
import Beng.Types.Things (Thing)

import GHC.Records (HasField)

-- instances

instance HasField "op" (Op -> Fallible a) (Thing -> Fallible a)

instance HasField "op" (i -> Op -> Fallible a) (i -> Thing -> Fallible a)

instance HasField "op" (i -> j -> Op -> Fallible a) (i -> j -> Thing -> Fallible a)

instance HasField "args" Definition ([(String, Thing -> Fallible ())] -> Op -> Fallible ())

instance HasField "null" Definition (Op -> Fallible ())

argAssertionsOf :: Definition -> [(String, Thing -> Fallible ())] -> Op -> Fallible ()