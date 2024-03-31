module Beng.Errors where

import Utils.Fallible (IsError)
import Utils.Messaging (Messagable)

import Beng.Types.Errors (Error)

instance Eq Error

instance Show Error

instance Messagable Error

instance IsError Error
