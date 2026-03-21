{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}

module Beng.Types.Parse.Patterns where

import Utils.Messaging (Messagable)
import Utils.Populace (Populace)
import qualified Utils.Populace as P

import qualified Data.Map.Ordered as OMap
import Data.Typeable (Typeable)
import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.PatternArguments (Arguments)
import qualified Beng.Types.Parse.Parsers as General
import qualified Beng.Types.Parse.Parsers.Code as Code

data SomePattern = forall p. Pattern p => SomePattern p

data Mismatch
data Comparison
data ComparatorState
type ComparatorParse = General.Parse Comparison ComparatorState ()
type ComparatorParses = General.Parses Mismatch Comparison ComparatorState ()
type ComparatorRunner = General.ParseRunner Mismatch Comparison ComparatorState ()
type Comparator = General.Parser Mismatch Comparison ComparatorState ()
data CharRange
data Space
data Literal
data CharClass
data NamedText
data Or
data And
data Delimited
data ArgP

class (Eq p, Show p, Messagable p, Typeable p) => Pattern p where
	parse :: p -> Code.Parser Match
	compareFrom :: p -> Comparator
	showPatternWith :: Bool -> p -> String
	getSubpatterns :: p -> Populace SomePattern
	getSubpatterns = P.singleton . SomePattern
	mustHavePrefix :: p -> Bool
	mustHaveSuffix :: p -> Bool
	canHavePrefix :: p -> Bool
	canHaveSuffix :: p -> Bool
	isOptional :: p -> Bool
	hasArgs :: p -> Bool
	hasArgs = not . OMap.null . getArgs
	getArgsUsing :: (SomePattern -> Arguments) -> p -> Arguments
	getArgsUsing _ _ = OMap.empty
	getArgs :: p -> Arguments
	getArgs = getArgsUsing getArgsOf
	getNonStructuralArgs :: p -> Arguments
	getNonStructuralArgs = getArgsUsing getNonStructuralArgsOf
	getRequiredArgs :: p -> Arguments
	getRequiredArgs = getArgsUsing getRequiredArgsOf

asPattern :: Pattern p => SomePattern -> Maybe p
getArgsOf :: SomePattern -> Arguments
getNonStructuralArgsOf :: SomePattern -> Arguments
getRequiredArgsOf :: SomePattern -> Arguments
