module Beng.Parse.Patterns.CharClass where

import Utils.Populace (Populace)

import Beng.Types.Parse.Matches (Match)
import qualified Beng.Types.Parse.Parsers.Code as Code
import qualified Beng.Types.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Patterns (CharRange)

enumerate :: (Populace CharRange -> [Char])

any :: ((Char -> Bool) -> Populace CharRange -> Bool -> Bool)

all :: ((Char -> Bool) -> Populace CharRange -> Bool -> Bool)

has :: Char -> Populace CharRange -> Bool -> Bool

showClass :: Populace CharRange -> Bool -> String

parse :: Populace CharRange -> Bool -> Code.Parser Match

compareFrom :: Populace CharRange -> Bool -> PatternComparator.Parser
