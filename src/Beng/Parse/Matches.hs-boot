module Beng.Parse.Matches where

import Data.Map.Ordered (OMap)
import Data.Text.Lazy (Text)

import Beng.Types.Parse.Matches (Argument, Match)

getArgs :: Match -> OMap String Argument

toCode :: Match -> Text

hasArgs :: Match -> Bool

hasPrefix :: Match -> Bool

hasSuffix :: Match -> Bool
