module Beng.Errors where

import Utils.Fallible (IsError)
import Utils.Messaging (Messagable)
import Utils.Populace (Populace)

import Beng.Types.Errors (Error)

instance Eq Error

instance Show Error

instance Messagable Error

instance IsError Error

compoundErrorsUsing :: Ord e => (e -> Maybe (String, Populace e)) -> (String -> Populace e -> e) -> e -> e -> e

showCompoundErrorsUsing :: (e -> String) -> String -> Populace e -> String