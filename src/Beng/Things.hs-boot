module Beng.Things where

import Utils.Fallible (FallibleI, IsError)
import Utils.Messaging (Messagable)

import Beng.Types.Operators (SomeOperator)
import Beng.Types.Build.Context (Context)
import Beng.Types.Operators.Declarations (Declaration)
import Beng.Types.Operators.Definitions (Definition)
import Beng.Types.Build.TypeTest (TypeTestResult)
import Beng.Types.Things (Mismatch, SomeThing, Undefined)

import Data.Text.Lazy (Text)

instance Eq Mismatch

instance Show Mismatch

instance Messagable Mismatch

instance Ord Mismatch

instance IsError Mismatch

instance Eq SomeThing

instance Show SomeThing

instance Messagable SomeThing

toCode :: SomeThing -> Text

undefined :: Declaration -> FallibleI Undefined SomeThing

propsOf :: SomeThing -> [SomeOperator]

defsOf :: SomeThing -> [Definition]

satisfiesThing :: (Context, SomeThing) -> SomeThing -> TypeTestResult
