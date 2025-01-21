module Beng.Parse.Patterns.Literal where

import Beng.Types.Parse.Matches (Match)
import qualified Beng.Types.Parse.Parsers.Code as Code
import qualified Beng.Types.Parse.Parsers.PatternComparator as PatternComparator

import Data.Text.Lazy (Text)

parse :: Text -> Code.Parser Match

compareFrom :: Text -> PatternComparator.Parser