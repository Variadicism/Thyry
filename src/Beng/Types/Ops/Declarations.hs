module Beng.Types.Ops.Declarations (
	ArgContextBuilder,
	Associativity(..),
	Declaration(..)
) where

import Utils.Fallible

import Beng.Build.Types.Cards (Card)
import Beng.Build.Types.Context (PrecedenceBound)
import Beng.Parse.Types.Matches (Capture)
import Beng.Parse.Types.Patterns (Pattern)
import Beng.Types.Locations (Location)

import Data.Map (Map)

data Associativity = Lefty | Righty

type ArgContextBuilder =
	String  -- ^ The name of the argument for which context is needed.
	-> Map String Capture  -- ^ The arguments built so far; they may be needed to build the preop
	-> Location
	-> Fallible [Card]  -- ^ The Cards to appended to context to parse the preop.
{- TODO: The Location parameter is TEMPORARY and should be removed later!
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
	pattern :: Pattern,
	associativity :: Associativity,
	precedence :: PrecedenceBound,
	contextualize :: ArgContextBuilder }