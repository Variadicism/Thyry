module Beng.Things where

import Utils.Fallible (FallibleI, IsError)
import Utils.Messaging (Messagable)

import Beng.Types.Operators (SomeOperator)
import Beng.Types.Build.Context (Context)
import Beng.Types.Operators.Declarations (Declaration)
import Beng.Types.Operators.Definitions (Definition)
import Beng.Types.Build.TypeTest (TypeTestResult)
import Beng.Types.Things (Mismatch, Thing, Undefined, Thing)

import Data.Text.Lazy (Text)

instance Eq Mismatch

instance Show Mismatch

instance Messagable Mismatch

instance Ord Mismatch

instance IsError Mismatch

instance Eq Thing

instance Show Thing

instance Messagable Thing

toCode :: Thing -> Text

undefined :: Declaration -> FallibleI Undefined Thing

propsOf :: Thing -> [SomeOperator]

defsOf :: Thing -> [Definition]

satisfies :: (Context, Thing) -> Thing -> TypeTestResult
