module Beng.Operators (
	Operator(..),
	SomeOperator(..),
	isNullary,
	canHavePrefix,
	canHaveSuffix,
	mustHavePrefix,
	mustHaveSuffix,
	nameAsValue,
	satisfies,
	filterDefs
) where

import Utils.Fallible
import qualified Utils.Maps.Ordered as UOMap
import Utils.Messaging (Messagable, debug, debugM, msg)

import {-# SOURCE #-} qualified Beng.Build.Context as C
import {-# SOURCE #-} qualified Beng.Build.TypeTest as TypeTest
import Beng.Locations ()
import Beng.Invocations (Invocation(..))
import qualified Beng.Operators.Declarations as Dec
import Beng.Operators.Declarations (Declaration(..), isReturnTypeMismatch)
import qualified Beng.Operators.Definitions as Def
import Beng.Operators.Definitions (Definition(..))
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import qualified Beng.Types.Operators as Ops
import Beng.Types.Operators (Operator, SomeOperator(..))
import qualified Beng.Types.Build.Context as TContext
import Beng.Types.Build.TypeTest (TypeTest(..))
import qualified Beng.Types.Build.TypeTest as TTest
import Beng.Types.Errors (Error(..))
import qualified Beng.Types.Locations as TLocation
import Beng.Types.Invocations (SomeInvocation(..))
import qualified Beng.Types.Operators.Declarations as TDec
import {-# SOURCE #-} Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Patterns (Literal(..), SomePattern(..))
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Matches (value)
import Beng.Types.Things (Mismatch(..))
import qualified Beng.Types.Things as TThing

import Control.Exception.Extra (Partial)
import Data.List (find)
import qualified Data.Map.Ordered as OMap
import Data.Maybe (catMaybes, isJust)
import Control.Monad (void)
import Data.Text.Lazy (unpack)
import Data.Typeable (cast)
import GHC.Records (HasField, getField)

instance Operator Declaration where
	location = Dec.location
	decLoc = Dec.location
	pattern = Dec.pattern
	returnType = Dec.returnType
	associativity = Dec.associativity
	precedence = Dec.precedence
	contextualize = Dec.contextualize
	inlineDefinition _ = Nothing
	hasProp test declaration = do
		void $ case C.has test $ SomeOperator declaration of
			Falue _ -> do
				debugM $ "SATISFIED declaration prop: " ++ show declaration
				Falue ()
			Error e -> do
				let unsatisfiedError = UnsatisfiedProperty (SomeOperator declaration) e
				debugM $ "UNSATISFIED declaration prop: " ++ show unsatisfiedError
				Error unsatisfiedError
	runUsing invocation@Invocation{operator = declaration, ..} = do
		let args = OMap.toMap $ UOMap.map value $ Match.getArgs match
		let sameDeclaration :: SomeOperator -> Bool = \candidate ->
			candidate.decLoc == Dec.location declaration
		case find sameDeclaration context.deck of
			Nothing -> Error $ UndefinedError { caller = SomeInvocation invocation }
			Just (SomeOperator candidate) -> case Ops.inlineDefinition candidate of
				Nothing -> Error $ UndefinedError { caller = SomeInvocation invocation }
				Just definition -> Def.runWith definition args

instance Operator Definition where
	location = Def.location
	decLoc = Dec.location . Def.declaration
	pattern = Dec.pattern . Def.declaration
	returnType = Dec.returnType . Def.declaration
	associativity = Dec.associativity . Def.declaration
	precedence = Dec.precedence . Def.declaration
	contextualize = Dec.contextualize . Def.declaration
	inlineDefinition = Just
	hasProp test definition = do
		let prop = SomeOperator definition
		let propTest :: TypeTest = do
			let propsContext = C.fromThings [test.current.candidate]
			debug "Restricing test context to props for definition prop"
				test { TTest.context = propsContext }

		void $ case C.has propTest prop of
			Falue _ -> do
				debugM $ "SATISFIED definition prop: " ++ show definition
				Falue ()
			Error e -> if isReturnTypeMismatch e then do
				let obscureError = ObscuredProperty prop e
				debugM $ "UNSATISFIED prop due to obscuring: " ++ show obscureError
				Error obscureError
			else do
				debugM $ "SATISFIED definition prop by itself (no match in context, " ++
					"but no obscuring operator): " ++ show definition
				Falue ()
	runUsing Invocation{operator = definition, match} = Def.runWith definition $
		OMap.toMap $ UOMap.map value $ Match.getArgs match

instance Operator SomeOperator where
	location (SomeOperator op) = Ops.location op
	decLoc (SomeOperator op) = Ops.decLoc op
	pattern (SomeOperator op) = Ops.pattern op
	returnType (SomeOperator op) = Ops.returnType op
	associativity (SomeOperator op) = Ops.associativity op
	precedence (SomeOperator op) = Ops.precedence op
	contextualize (SomeOperator op) = Ops.contextualize op
	inlineDefinition (SomeOperator op) = Ops.inlineDefinition op
	hasProp test (SomeOperator op) = Ops.hasProp test op
	runUsing Invocation{operator = SomeOperator op, context, match, location} =
		Ops.runUsing Invocation{operator = op, context, match, location}

instance HasField "location" SomeOperator TLocation.Location where
	getField (SomeOperator op) = Ops.location op

instance HasField "decLoc" SomeOperator TLocation.Location where
	getField (SomeOperator op) = Ops.decLoc op

instance HasField "pattern" SomeOperator TPattern.SomePattern where
	getField (SomeOperator op) = Ops.pattern op

instance HasField "returnType" SomeOperator TThing.SomeThing where
	getField (SomeOperator op) = Ops.returnType op

instance HasField "associativity" SomeOperator TDec.Associativity where
	getField (SomeOperator op) = Ops.associativity op

instance HasField "precedence" SomeOperator TContext.PrecedenceBound where
	getField (SomeOperator op) = Ops.precedence op

instance HasField "contextualize" SomeOperator TDec.ArgContextBuilder where
	getField (SomeOperator op) = Ops.contextualize op

instance Eq SomeOperator where
	op1 == op2 =
		op1.location == op2.location &&
		op1.decLoc == op2.decLoc &&
		isDefinition op1 == isDefinition op2

instance Show SomeOperator where
	show (SomeOperator op) = show op

instance Messagable SomeOperator where
	msg (SomeOperator op) = msg op

instance Ord SomeOperator where
	compare op1 op2 =
		compare op1.location op2.location <>
		compare op1.decLoc op2.decLoc <>
		compare (isDefinition op1) (isDefinition op2)

isNullary :: Operator op => op -> Bool
isNullary op = not $ Pattern.hasArgs $ Ops.pattern op

canHavePrefix :: Operator op => op -> Bool
canHavePrefix op = Pattern.canHavePrefix $ Ops.pattern op

canHaveSuffix :: Operator op => op -> Bool
canHaveSuffix op = Pattern.canHaveSuffix $ Ops.pattern op

mustHavePrefix :: Operator op => op -> Bool
mustHavePrefix op = Pattern.mustHavePrefix $ Ops.pattern op

mustHaveSuffix :: Operator op => op -> Bool
mustHaveSuffix op = Pattern.mustHaveSuffix $ Ops.pattern op

nameAsValue :: (Partial, Operator op) => op -> String
nameAsValue op = case Ops.pattern op of
	SomePattern pattern -> case cast pattern of
		Just (Literal name) -> unpack name
		Nothing -> error "Expected literal declaration pattern"

satisfies :: (Operator super, Operator sub) => (TypeTest, super) -> sub -> FallibleI TDec.Mismatch ()
satisfies (test, super) sub = do
	debugM $ "Testing satisfaction of operator:\n" ++
		"\tSuper: " ++ show super ++ "\n\tSub: " ++ show sub
	if Ops.decLoc super == Ops.decLoc sub then do
		debugM $ "Satisfies because the operators have equal declarations"
		Falue ()
	else do
		let patternResult = mapError TDec.PatternMismatch $
			(test, Ops.pattern super) `Pattern.satisfies` Ops.pattern sub
		case patternResult of
			Falue _ -> do
				debugM $ "Satisfied PATTERN of operator:\n\t✓ Super" ++ show (Ops.pattern super) ++
					"\n\t✓ Sub: " ++ show (Ops.pattern sub) ++
					"\nComparing return types next:\n\t? Super:" ++ show (Ops.returnType super) ++
					"\n\t? Sub: "
				let returnTypeResult = mapError TDec.ReturnTypeMismatch $
					(test, Ops.returnType sub) `TypeTest.satisfiesDuring` Ops.returnType super
				case returnTypeResult of
					Falue _ -> debugM $ "SATISFIED operator:\n\t✓ Super:" ++ show (Ops.returnType super) ++
						"\n\t✓ Sub: " ++ show (Ops.returnType sub)
					Error returnTypeError -> debugM $ "UNsatisfied RETURN TYPE of operator:\n\t╳ Super:" ++
						show (Ops.returnType super) ++ "\n\t╳ Sub: " ++ show (Ops.returnType sub) ++
						"\n\tReason: " ++ show returnTypeError
				returnTypeResult
			Error patternError -> do
				debugM $ "UNSATISFIED operator by pattern mismatch:\n\t╳ Super: " ++ show (Ops.pattern super) ++
					"\n\t╳ Sub: " ++ show (Ops.pattern sub) ++ "\n\tReason: " ++ show patternError
				Error patternError

filterDefs :: [SomeOperator] -> [Definition]
filterDefs = catMaybes . map maybeDefinition
	where
		maybeDefinition :: SomeOperator -> Maybe Definition
		maybeDefinition (SomeOperator op) = Ops.inlineDefinition op

isDefinition :: SomeOperator -> Bool
isDefinition (SomeOperator op) = isJust $ Ops.inlineDefinition op
