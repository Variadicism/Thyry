module Beng.Ops.Declarations (
	ArgContextBuilder,
	Associativity(..),
	Declaration(..),
	PrecedenceBound(..),
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix,
	nameAsValue,
	satisfies
) where

import Utils.Fallible
import Utils.Messaging (Messagable, msg)
import qualified Utils.Populace as P

import {-# SOURCE #-} Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import Beng.Types.Build.Context (Context, PrecedenceBound(..))
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Patterns (Pattern(Literal))
import Beng.Locations ()
import Beng.Types.Ops.Declarations (ArgContextBuilder, Associativity(..), Declaration(..), Mismatch(..))
import {-# SOURCE #-} Beng.Values (oneIsA)

import Control.Exception.Extra (Partial)
import Data.Text.Lazy (unpack)
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
			PatternMismatch{} -> 1
			ReturnTypeMismatch{} -> 2
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
	show dec = show dec.location ++ "\\" ++ msg dec.pattern ++ " => " ++ show dec.returnType

instance Messagable Declaration where
	msg Declaration{pattern} = msg pattern

instance HasField "name" Declaration String where
	getField = nameAsValue

-- exported

isNullary :: (Declaration -> Bool)
isNullary = not . Pattern.hasArgs . pattern

canHavePrefix :: Declaration -> Bool
canHavePrefix = Pattern.canHavePrefix . pattern

canHaveSuffix :: Declaration -> Bool
canHaveSuffix = Pattern.canHaveSuffix . pattern

mustHavePrefix :: Declaration -> Bool
mustHavePrefix = Pattern.mustHavePrefix . pattern

mustHaveSuffix :: Declaration -> Bool
mustHaveSuffix = Pattern.mustHaveSuffix . pattern

nameAsValue :: Partial => Declaration -> String
nameAsValue declaration = do
	let (Literal name) = declaration.pattern
	unpack name

satisfies :: (Context, Declaration) -> Declaration -> FallibleI Mismatch ()
satisfies (context, super) sub = do
	mapError ReturnTypeMismatch $ (context, super.returnType) `oneIsA` sub.returnType
	mapError PatternMismatch $ (context, super.pattern) `Pattern.satisfies` sub.pattern
