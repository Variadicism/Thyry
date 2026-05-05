module Beng.Operators.Declarations (
	ArgContextBuilder,
	Associativity(..),
	Declaration(..),
	PrecedenceBound(..),
	isReturnTypeMismatch
) where

import Utils.Fallible
import Utils.Messaging (Messagable, msg)
import qualified Utils.Populace as P

import {-# SOURCE #-} Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import Beng.Locations ()
import Beng.Types.Build.Context (PrecedenceBound(..))
import Beng.Types.Parse.Patterns (Literal(..), SomePattern(..))
import {-# SOURCE #-} Beng.Things ()
import Beng.Types.Operators.Declarations (ArgContextBuilder, Associativity(..), Declaration(..), Mismatch(..))

import Data.Text.Lazy (unpack)
import Data.Typeable (cast)
import GHC.Records (HasField, getField)

-- instances

deriving instance Eq Associativity

deriving instance Show Associativity

deriving instance Eq Mismatch

instance Show Mismatch where
	show PatternMismatch{..} = show patternMismatch
	show ReturnTypeMismatch{..} = show typeMismatch
	show CompoundMismatch{..} = showCompoundErrorsUsing show context compound

instance Messagable Mismatch where
	msg PatternMismatch{..} = msg patternMismatch
	msg ReturnTypeMismatch{..} = msg typeMismatch
	msg CompoundMismatch{..} = showCompoundErrorsUsing msg context compound

instance Ord Mismatch where
	compare p1@PatternMismatch{} p2@PatternMismatch{} = compare p1.patternMismatch p2.patternMismatch
	compare r1@ReturnTypeMismatch{} r2@ReturnTypeMismatch{} = compare r1.typeMismatch r2.typeMismatch
	compare m CompoundMismatch{..} = compare m compound.head
	compare CompoundMismatch{..} m = compare compound.head m
	compare m1 m2 = compare (typeIndex m1) (typeIndex m2)
		where typeIndex = \case
			ReturnTypeMismatch{} -> 1
			PatternMismatch{} -> 2
			CompoundMismatch{} -> 3  -- Impossible

instance IsError Mismatch where
	prepend context = \case
		p@PatternMismatch{} -> p{ patternMismatch = prepend context p.patternMismatch }
		r@ReturnTypeMismatch{} -> r{ typeMismatch = prepend context r.typeMismatch }
		c@CompoundMismatch{} -> c{ context = context ++ c.context }
	(<!>) p1@PatternMismatch{} p2@PatternMismatch{} =
		PatternMismatch $ p1.patternMismatch <!> p2.patternMismatch
	(<!>) r1@ReturnTypeMismatch{} r2@ReturnTypeMismatch{} =
		ReturnTypeMismatch $ r1.typeMismatch <!> r2.typeMismatch
	(<!>) m1 m2 = do
		let getCompound = \case
			CompoundMismatch{..} -> Just (context, compound)
			_ -> Nothing
		compoundErrorsUsing getCompound CompoundMismatch m1 m2

instance Eq Declaration where
	(==) d1 d2 = d1.location == d2.location

instance Show Declaration where
	show dec = show dec.location ++ "\\" ++ msg dec.pattern ++ " => " ++ msg dec.returnType

instance Messagable Declaration where
	msg Declaration{..} = "\\" ++ msg pattern ++ " => " ++ msg returnType

instance Ord Declaration where
	compare d1 d2 = compare d1.location d2.location

instance HasField "name" Declaration String where
	getField Declaration{pattern} = case pattern of
		SomePattern namedPattern -> case cast namedPattern of
			Just (Literal name) -> unpack name
			Nothing -> error "Expected literal declaration pattern"

-- exported

isReturnTypeMismatch :: (Mismatch -> Bool)
isReturnTypeMismatch = \case
	ReturnTypeMismatch _ -> True
	PatternMismatch _ -> False
	CompoundMismatch{..} -> all isReturnTypeMismatch compound
