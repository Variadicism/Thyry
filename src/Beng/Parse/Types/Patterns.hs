module Beng.Parse.Types.Patterns (
	Pattern(..)
) where

import qualified Beng.Parse.Types.Arguments as Arg

import Data.Text.Lazy (Text)

data Pattern =
	Space |
	Literal { literal :: Text } |
	Or { subpatterns :: [Pattern] } |
	And { subpatterns :: [Pattern] } |
	-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me! :P
	Delimited { delimiter :: Pattern, delimitend :: Pattern } |
	Argument { arg :: Arg.Definition }