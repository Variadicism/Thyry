{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}

module Beng.Types.Parse.Patterns (
	Mismatch(..),
	Comparison(..),
	ComparatorState(..),
	ComparatorParse,
	ComparatorParses,
	ComparatorRunner,
	Comparator,
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
	ArgP(..),
	Arguments,
	asPattern,
	getArgsOf,
	getNonStructuralArgsOf,
	getRequiredArgsOf,
	Pattern(..)
) where

import Utils.Messaging (Messagable, msg)
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (Populace2)

import Beng.Types.Locations (Location)
import Beng.Types.Parse.Matches (Match)
import Beng.Types.Parse.PatternArguments (Argument(..), Arguments)
import qualified Beng.Types.Parse.Parsers.Code as Code
import Beng.Types.Build.TypeTest (TypeTest)
import qualified Beng.Types.Parse.Parsers as General

import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (Text)
import Data.Typeable (Typeable, cast)

data SomePattern = forall p. Pattern p => SomePattern p

data Mismatch =
	-- \/ closest to success
	LeftoverSuper { leftover :: Populace SomePattern } |
	LeftoverSub { leftover :: Populace SomePattern } |
	Mismatch { nextSub :: SomePattern, remainingSuper :: Populace SomePattern } |
	-- /\ furthest from success
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

data Comparison = Comparison {
	sub :: [SomePattern],
	super :: [SomePattern] }

data ComparatorState = ComparatorState {
	indentation :: Int,
	rest :: Comparison,
	checkArgTypes :: Bool,
	test :: TypeTest }

type ComparatorParse = General.Parse Comparison ComparatorState ()
type ComparatorParses = General.Parses Mismatch Comparison ComparatorState ()
type ComparatorRunner = General.ParseRunner Mismatch Comparison ComparatorState ()
type Comparator = General.Parser Mismatch Comparison ComparatorState ()

-- I could implement this with Haskell ranges, but I want to Show them nicely.
data CharRange = CharRange { start :: Char, end :: Char }

data Space = Space deriving (Eq, Show)

data Literal = Literal { literal :: Text } deriving (Eq, Show)

data CharClass = CharClass { ranges :: Populace CharRange, negate :: Bool }

data NamedText = NamedText { name :: String, subpattern :: SomePattern, decLoc :: Location }

data Or = Or { subpatterns :: Populace2 SomePattern } deriving (Eq, Show)

data And = And { subpatterns :: Populace2 SomePattern } deriving (Eq, Show)

-- Yeah, I made up "delimitend" akin to "dividend" and "subtrahend". So?! Come at me! :P
data Delimited = Delimited { delimiter :: SomePattern, delimitend :: SomePattern } deriving (Eq, Show)

data ArgP = ArgP Argument

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

instance Eq SomePattern where
	SomePattern p1 == SomePattern p2 = maybe False (p1 ==) $ cast p2

instance Show SomePattern where
	show (SomePattern p) = '\\' : showPatternWith False p

instance Messagable SomePattern where
	msg (SomePattern p) = '\\' : showPatternWith True p

getArgsOf :: SomePattern -> Arguments
getArgsOf (SomePattern p) = getArgs p

asPattern :: Pattern p => SomePattern -> Maybe p
asPattern (SomePattern p) = cast p

getNonStructuralArgsOf :: SomePattern -> Arguments
getNonStructuralArgsOf (SomePattern p) = getNonStructuralArgs p

getRequiredArgsOf :: SomePattern -> Arguments
getRequiredArgsOf (SomePattern p) = getRequiredArgs p
