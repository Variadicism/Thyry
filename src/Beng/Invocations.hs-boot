module Beng.Invocations where

import Utils.Messaging (Messagable)

import Beng.Types.Invocations (Invocation, SomeInvocation)
import Beng.Types.Parse.Matches (Argument)

import Data.Map.Ordered (OMap)
import Data.Text.Lazy (Text)

instance Eq op => Eq (Invocation op)

instance Show op => Show (Invocation op)

instance Messagable op => Messagable (Invocation op)

instance Show SomeInvocation

instance Messagable SomeInvocation

instance Eq SomeInvocation

isNullary :: SomeInvocation -> Bool

hasPrefix :: SomeInvocation -> Bool

hasSuffix :: SomeInvocation -> Bool

getArgs :: SomeInvocation -> OMap String Argument

toCode :: SomeInvocation -> Text
