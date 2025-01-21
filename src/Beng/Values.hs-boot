module Beng.Values where

import Utils.Fallible (FallibleI, IsError)
import Utils.Messaging (Messagable)

import Beng.Types.Build.Context (Context)
import Beng.Types.Ops.Declarations (Declaration)
import Beng.Types.Values (Mismatch, Type, Undefined, Value)

import Data.Text.Lazy (Text)

instance Eq Mismatch

instance Show Mismatch

instance Messagable Mismatch

instance Ord Mismatch

instance IsError Mismatch

instance Eq Type

instance Show Type

instance Messagable Type

instance Eq Value

instance Show Value

instance Messagable Value

toCode :: Value -> Text

undefined :: Declaration -> FallibleI Undefined Value

oneIsA :: (Context, Type) -> Type -> FallibleI Mismatch ()