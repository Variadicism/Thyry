module Beng.Parse.Types.Patterns (
	ArgumentType(..),
	CharRange(..),
	Pattern(..)
) where

import Data.Text.Lazy (Text)

data ArgumentType =
	OpType |
	-- This name refers to the "string" in Beng, not in Haskell.
	StringType |
	ListType { element :: ArgumentType } |
	MaybeType { inner :: ArgumentType }

-- I could implement this with Haskell ranges, but I want to Show them nicely.
data CharRange = CharRange { start :: Char, end :: Char }

data Pattern =
	Space |
	Literal { literal :: Text } |
	CharClass { chars :: [Char], ranges :: [CharRange], negate :: Bool } |
	NamedText { name :: String, subpattern :: Pattern } |
	Or { subpatterns :: [Pattern] } |
	And { subpatterns :: [Pattern] } |
	-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me! :P
	Delimited { delimiter :: Pattern, delimitend :: Pattern } |
	Argument { name :: String }