module Beng.Ops.Declarations (
	ArgContextBuilder,
	Associativity(..),
	Declaration(..),
	PrecedenceBound(..),
	isReturnTypeMismatch,
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix,
	nameAsValue,
	satisfies
) where

import Utils.Fallible
import Utils.Messaging (Messagable, debugM, msg)
import qualified Utils.Populace as P

import {-# SOURCE #-} Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import Beng.Locations ()
import {-# SOURCE #-} qualified Beng.SatisfactionTest as ST
import Beng.Types.Build.Context (PrecedenceBound(..))
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Parse.Patterns (Pattern(Literal))
import {-# SOURCE #-} Beng.Things ()
import Beng.Types.Ops.Declarations (ArgContextBuilder, Associativity(..), Declaration(..), Mismatch(..))
import Beng.Types.SatisfactionTest (SatisfactionTest)

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
	show dec = show dec.location ++ msg dec.pattern ++ " => " ++ msg dec.returnType

instance Messagable Declaration where
	msg Declaration{..} = msg pattern ++ " => " ++ msg returnType

instance Ord Declaration where
	compare d1 d2 = compare d1.location d2.location

instance HasField "name" Declaration String where
	getField = nameAsValue

-- exported

isReturnTypeMismatch :: (Mismatch -> Bool)
isReturnTypeMismatch = \case
	ReturnTypeMismatch _ -> True
	PatternMismatch _ -> False
	CompoundMismatch{..} -> all isReturnTypeMismatch compound

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

satisfies :: (SatisfactionTest, Declaration) -> Declaration -> FallibleI Mismatch ()
satisfies (test, super) sub = do
	debugM $ "Testing satisfaction of declaration:\n" ++
		"\tSuper: " ++ show super ++ "\n\tSub: " ++ show sub
	if super == sub then do
		debugM $ "Satisfies because the declarations are equal"
		Falue ()
	else do
		let patternResult = mapError PatternMismatch $
			(test, super.pattern) `Pattern.satisfies` sub.pattern
		case patternResult of
			Falue _ -> do
				{- debugM $ "Satisfied PATTERN of declaration:\n\t✓ Super" ++ show super.pattern ++
					"\n\t✓ Sub: " ++ show sub.pattern ++
					"\nComparing return types next:\n\t? Super:" ++ show super.returnType  ++
					"\n\t? Sub: " -}
				let returnTypeResult = mapError ReturnTypeMismatch $
					(test, sub.returnType) `ST.satisfiesDuring` super.returnType
				{- case returnTypeResult of
					Falue _ -> debugM $ "SATISFIED declaration:\n\t✓ Super:" ++ show super.returnType ++
						"\n\t✓ Sub: " ++ show sub.returnType
					Error returnTypeError -> debugM $ "UNsatisfied RETURN TYPE of declaration:\n\t╳ Super:" ++
						show super.returnType ++ "\n\t╳ Sub: " ++ show sub.returnType ++
						"\n\tReason: " ++ show returnTypeError -}
				returnTypeResult
			Error patternError -> do
				{- debugM $ "UNsatisfied declaration by pattern mismatch:\n\t╳ Super: " ++ show super.pattern ++
					"\n\t╳ Sub: " ++ show sub.pattern ++ "\n\tReason: " ++ show patternError -}
				Error patternError