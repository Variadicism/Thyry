module Beng.Parse.Patterns.CharClass where

import Utils.Populace (Populace)

import Beng.Types.Parse.Matches (SomeMatch)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Parse.Patterns (CharClass, CharRange, Pattern)

enumerate :: (Populace CharRange -> [Char])

any :: ((Char -> Bool) -> Populace CharRange -> Bool -> Bool)

all :: ((Char -> Bool) -> Populace CharRange -> Bool -> Bool)

has :: Char -> Populace CharRange -> Bool -> Bool

showClass :: Populace CharRange -> Bool -> String

parse :: CharClass -> Code.Parser SomeMatch
instance Pattern CharClass
