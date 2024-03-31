module Beng.Ops where

import Utils.Messaging (Messagable)

import Beng.Ops.Types (Op)
import Beng.Parse.Types.Matches (Parameter)

import Data.Map.Ordered (OMap)
import Data.Text.Lazy (Text)

instance Eq Op

instance Show Op

instance Messagable Op

isNullary :: Op -> Bool

hasPrefix :: Op -> Bool

hasSuffix :: Op -> Bool

getArgs :: Op -> OMap String Parameter

toCode :: Op -> Text