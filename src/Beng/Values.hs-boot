module Beng.Values where

import Utils.Fallible (FallibleI)
import Utils.Messaging (Messagable)

import Beng.Ops.Types.Declarations (Declaration)
import Beng.Values.Types (Type, Undefined, Value)

import Data.Text.Lazy (Text)

instance Eq Type

instance Show Type

instance Messagable Type

instance Eq Value

instance Show Value

instance Messagable Value

toCode :: Value -> Text

undefined :: Declaration -> FallibleI Undefined Value