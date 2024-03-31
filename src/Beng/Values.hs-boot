module Beng.Values where

import Utils.Messaging (Messagable)

import Beng.Values.Types (Type, Value)

import Data.Text.Lazy (Text)

instance Eq Type

instance Show Type

instance Messagable Type

instance Eq Value

instance Show Value

instance Messagable Value

toCode :: Value -> Text