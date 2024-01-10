module Beng.Parse.Types.Patterns (
	Pattern(..)
) where

import Beng.Run.Types.Values (ValueType)

import Data.Text.Lazy (Text)

data Pattern =
	Space |
	Literal { literal :: Text } |
	Or { subpatterns :: [Pattern] } |
	And { subpatterns :: [Pattern] } |
	-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me! :P
	Delimited { delimiter :: Pattern, delimitend :: Pattern } |
	Argument { name :: String, valueType :: ValueType }