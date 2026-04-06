{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}

module Beng.Types.Parse.Patterns where

import Utils.Messaging (Messagable)
import Utils.Populace (Populace)
import qualified Utils.Populace as P

import qualified Data.Map.Ordered as OMap
import Data.Set (Set)
import Data.Typeable (Typeable)
import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.PatternArguments (Arguments)
import qualified Beng.Types.Parse.Parsers as General
import qualified Beng.Types.Parse.Parsers.Code as Code

data SomePattern = forall p m. Pattern m p => SomePattern p

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

class (Match m, Eq p, Show p, Messagable p, Typeable p) => Pattern m p | p -> m where
	parse :: p -> Code.Parser m
	compareAsSub :: p -> Comparator
	compareAsSuper :: p -> Comparator
	getSubpatterns :: p -> Populace SomePattern
	getSubpatterns = P.singleton . SomePattern
	mustHavePrefix :: p -> Bool
	mustHaveSuffix :: p -> Bool
	canHavePrefix :: p -> Bool
	canHaveSuffix :: p -> Bool
	canMatchEmpty :: p -> Bool
	startingSpaceStates :: p -> Set Code.SpaceState
	startingSpaceStates _ = mempty
	isOptional :: p -> Bool
	hasArgs :: p -> Bool
	hasArgs = not . OMap.null . getArgs
	getArgsUsing :: (SomePattern -> Arguments) -> p -> Arguments
	getArgsUsing _ _ = OMap.empty
	getArgs :: p -> Arguments
	getArgs = getArgsUsing $ \(SomePattern p') -> getArgs p'
	getNonStructuralArgs :: p -> Arguments
	getNonStructuralArgs = getArgsUsing $ \(SomePattern p') -> getNonStructuralArgs p'
	getRequiredArgs :: p -> Arguments
	getRequiredArgs = getArgsUsing $ \(SomePattern p') -> getRequiredArgs p'
