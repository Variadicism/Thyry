module Beng.Build.Context where

import Utils.Fallible (FallibleI)

import Beng.Types.Build.Context (Context)
import Beng.Types.Build.TypeTest (TypeTest)
import Beng.Types.Operators (Operator)
import qualified Beng.Types.Operators.Declarations as Declaration
import Beng.Types.Things (Thing)

fromThings :: [Thing] -> Context

has :: Operator op => TypeTest -> op -> FallibleI Declaration.Mismatch ()
