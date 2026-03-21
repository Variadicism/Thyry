module Beng.Types.Ops.Declarations (
	Mismatch(..),
	ArgContextBuilder,
	Associativity(..),
	Declaration(..)
) where

import Utils.Populace (Populace)

import {-# SOURCE #-} Beng.Parse.Patterns ()
import Beng.Types.Build.Cards (Card)
import Beng.Types.Build.Context (PrecedenceBound)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Patterns (SomePattern)
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Types.Errors (Fallible)
import Beng.Types.Locations (Location)
import {-# SOURCE #-} Beng.Types.Things (Thing)
import {-# SOURCE #-} qualified Beng.Types.Things as Thing

import Data.Map (Map)

data Associativity = Lefty | Righty

data Mismatch =
	ReturnTypeMismatch { typeMismatch :: Thing.Mismatch } |
	PatternMismatch { patternMismatch :: Pattern.Mismatch } |
	CompoundMismatch { context :: String, compound :: Populace Mismatch }

type ArgContextBuilder =
	String  -- ^ The name of the argument for which context is needed.
	-> Map String Match.Argument  -- ^ The arguments built so far; they may be needed to build the preop
	-> Location
	-> Fallible [Card]  -- ^ The Cards to appended to context to parse the preop.
{- TODO: The Location field is TEMPORARY and should be removed later!
   In the future, the Card should use the Location of the Declaration passed into `build...using`.
   However, we can't use `build...using` until the type system is working.
   In the meantime, we need some declaration-generating builtin ops.
   They will be using the Location of the argument for which the Context is being generated for now.

   Note: it's possible (extremely unlikely) that a Declaration could be made at the very start of
   a preop argument, which would result in generated Cards and the coded Card having the same
   location and therefore be considered equal under Eq Declaration or Eq Definition. Again, this
   is temporary and will be fixed when we have a type system to implement `build...using`.

   Note: when `build...using` is finally implemented, we'll need an extra piece of Location id
   for cases where multiple declarations are generated at one code location using string insertions
   through multi-target operations like list mapping. This could be the index of the Declaration in
   the list passed to `build...using`. -}

data Declaration = Declaration {
	location :: Location,
	pattern :: SomePattern,
	returnType :: Thing,  -- TODO: use types from args to formulate the return type
	associativity :: Associativity,
	precedence :: PrecedenceBound,
	contextualize :: ArgContextBuilder }
