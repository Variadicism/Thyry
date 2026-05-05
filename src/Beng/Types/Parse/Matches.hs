module Beng.Types.Parse.Matches (
	Argument(..),
	DelimitedTail(..),
	SomeMatch(..),
	Space(..),
	Literal(..),
	CharClass(..),
	NamedText(..),
	Or(..),
	And(..),
	Delimited(..),
	Match(..)
) where

import Utils.Messaging (Messagable)
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (Populace2)
import Utils.Fallible (FallibleI(..))

import qualified Beng.Types.Parse.PatternArguments as Pattern
import {-# SOURCE #-} Beng.Types.Build.TypeTest (ParameterMatchResults)
import Beng.Types.Locations (Location)
import {-# SOURCE #-} Beng.Types.Things (
	ParameterMatches,
	ResolveError,
	SomeParameterizedThing,
	SomeThing)

import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (Text)
import Data.Typeable (Typeable)

data Argument = Argument {
	pattern :: Pattern.Argument,
	matchedType :: SomeParameterizedThing,
	parameterMatches :: ParameterMatchResults,
	value :: SomeThing }

data SomeMatch = forall m. Match m => SomeMatch m

data DelimitedTail =
	DelimitedTailMatch (Populace (SomeMatch, SomeMatch)) |
	DelimitedTailMissing [Pattern.Argument]

data Space = Space { text :: Text }

data Literal = Literal { text :: Text }

data CharClass = CharClass { char :: Char }

data NamedText = NamedText { decLoc :: Location, name :: String, match :: SomeMatch }

data Or = Or { match :: SomeMatch, matchIndex :: Int, misses :: [Pattern.Argument] }

data And = And { matches :: Populace2 SomeMatch }

data Delimited = Delimited { head :: SomeMatch, tail :: DelimitedTail }

class (Eq m, Show m, Messagable m, Typeable m) => Match m where
	getSubmatches :: m -> Populace SomeMatch
	getSubmatches = P.singleton . SomeMatch

	toCode :: m -> Text

	getArgs :: m -> OMap String Argument
	getArgs _ = OMap.empty

	hasPrefix :: m -> Bool

	hasSuffix :: m -> Bool

	resolve :: ParameterMatches -> m -> FallibleI ResolveError SomeMatch
	resolve _ = Falue . SomeMatch
