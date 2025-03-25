module Beng.Ops where

import Utils.Messaging (Messagable)

import Beng.Types.Ops (Op)
import Beng.Types.Parse.Matches (Argument)

import Data.Map.Ordered (OMap)
import Data.Text.Lazy (Text)

instance Eq Op

instance Show Op

instance Messagable Op

isNullary :: Op -> Bool

hasPrefix :: Op -> Bool

hasSuffix :: Op -> Bool

getArgs :: Op -> OMap String Argument

toCode :: Op -> Text