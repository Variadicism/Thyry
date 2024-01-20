module Beng.Parse.Types.Patterns (
	CharRange(..),
	Pattern(..)
) where

import Data.Text.Lazy (Text)

-- I could implement this with Haskell ranges, but I want to Show them nicely.
data CharRange = CharRange { start :: Char, end :: Char }

data Pattern =
	Space |
	Literal { literal :: Text } |
	CharClass { chars :: [Char], ranges :: [CharRange], negate :: Bool } |
	Or { subpatterns :: [Pattern] } |
	And { subpatterns :: [Pattern] } |
	-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me! :P
	Delimited { delimiter :: Pattern, delimitend :: Pattern } |
	Argument { name :: String }