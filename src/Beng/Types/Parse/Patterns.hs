{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}

module Beng.Types.Parse.Patterns (
	Mismatch(..),
	SomePattern(..),
	CharRange(..),
	Argument(..),
	Space(..),
	Literal(..),
	CharClass(..),
	NamedText(..),
	Or(..),
	And(..),
	Delimited(..),
	Arguments,
	Pattern(..)
) where

import Utils.Messaging (Messagable)
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (Populace2)

import Beng.Types.Locations (Location)
import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.PatternArguments (Argument(..), Arguments)
import {-# SOURCE #-} Beng.Types.Parse.Parsers.PatternComparator (Comparator)
import qualified Beng.Types.Parse.Parsers.Code as Code

import qualified Data.Map.Ordered as OMap
import Data.Set (Set)
import Data.Text.Lazy (Text)
import Data.Typeable (Typeable)

data SomePattern = forall p m. Pattern m p => SomePattern p

data Mismatch =
	-- \/ closest to success
	LeftoverRequirement { leftover :: Populace SomePattern } |
	LeftoverCandidate { leftover :: Populace SomePattern } |
	Mismatch { nextCandidate :: SomePattern, remainingRequirement :: Populace SomePattern } |
	-- /\ furthest from success
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

-- I could implement this with Haskell ranges, but I want to Show them nicely.
data CharRange = CharRange { start :: Char, end :: Char }

data Space = Space deriving (Eq)

data Literal = Literal { literal :: Text } deriving (Eq)

data CharClass = CharClass { ranges :: Populace CharRange, negate :: Bool }

data NamedText = NamedText { name :: String, subpattern :: SomePattern, decLoc :: Location }

data Or = Or { subpatterns :: Populace2 SomePattern }

data And = And { subpatterns :: Populace2 SomePattern }

-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me! :P
data Delimited = Delimited { delimiter :: SomePattern, delimitend :: SomePattern }

class (Match m, Eq p, Show p, Messagable p, Typeable p) => Pattern m p | p -> m where
	parse :: p -> Code.Parser m
	compareAsCandidate :: p -> Comparator
	compareAsRequirement :: p -> Comparator

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
