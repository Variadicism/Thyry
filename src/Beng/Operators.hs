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
import qualified Utils.Maps.Ordered as OMap
import Utils.Messaging (Messagable, debug, debugM, msg)
import qualified Utils.Populace as P

import {-# SOURCE #-} qualified Beng.Build.Context as C
import {-# SOURCE #-} Beng.Build.TypeTest (satisfiesDuring)
import {-# SOURCE #-} Beng.Things ()
import Beng.Locations (Location)
import Beng.Invocations (Invocation(..))
import qualified Beng.Operators.Declarations as Dec
import Beng.Operators.Declarations
	(ArgContextBuilder, Associativity, Declaration(..), PrecedenceBound, isReturnTypeMismatch)
import qualified Beng.Operators.Definitions as Def
import Beng.Operators.Definitions (Definition(..))
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import qualified Beng.Types.Operators as Ops
import Beng.Types.Operators (Operator, SomeOperator(..))
import qualified Beng.Types.Build.Context as Context
import Beng.Types.Build.TypeTest (TypeTest(..))
import qualified Beng.Types.Build.TypeTest as Test
import Beng.Types.Errors (Error(..))
import Beng.Types.Invocations (SomeInvocation(..))
import qualified Beng.Types.Operators.Declarations as Dec
import Beng.Types.Operators.Declarations (Mismatch(..))
import {-# SOURCE #-} Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as Match
import Beng.Types.Parse.Patterns (Argument(..), Literal(..), SomePattern(..))
import Beng.Types.Parse.Matches (value)
import Beng.Types.Things (
	Binding(..),
	Mismatch(..),
	NamedThing(..),
	NativeBitsType(..),
	Parameter(..),
	SomeConcreteThing(..),
	SomeParameterizedThing(..),
	SomeThing(..))
import qualified Beng.Types.Things as Thing

import Control.Monad (guard)
import Control.Exception.Extra (Partial)
import Data.List (find)
import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap
import Data.Maybe (catMaybes, isJust)
import Data.Text.Lazy (unpack)
import Data.Typeable (cast)
import GHC.Records (HasField, getField)

missingParametersIn :: Thing.ResolveError -> [Parameter]
missingParametersIn = \case
	Thing.MissingParameter{parameter} -> [parameter]
	Thing.CompoundResolveError{compound} -> concatMap missingParametersIn compound.l

seedMissingParameters ::
	Thing.ParameterMatches ->
	[Parameter] ->
	Thing.ParameterMatches
seedMissingParameters = foldl seedMissingParameter
	where
		seedMissingParameter ::
			Thing.ParameterMatches ->
			Parameter ->
			Thing.ParameterMatches
		seedMissingParameter bindings parameter =
			if Map.member parameter bindings then
				bindings
			else
				Map.insert parameter
					(P.singleton Binding {
						location = parameter.decLoc,
						thing = parameter.baseType })
					bindings

resolveOrBaseType ::
	Thing.ParameterMatches ->
	SomeParameterizedThing ->
	SomeConcreteThing
resolveOrBaseType bindings requirement = case Thing.resolve bindings requirement of
	Falue resolved -> resolved
	Error resolveError -> do
		let missingParameters = missingParametersIn resolveError
		let newParameters = filter (not . (`Map.member` bindings)) missingParameters
		let seededBindings = seedMissingParameters bindings missingParameters
		if null newParameters then
			error $ "Internal resolve failure in Beng.Operators: " ++ show resolveError
		else
			resolveOrBaseType seededBindings requirement

instance Operator Declaration where
	location = Dec.location
	decLoc = Dec.location
	pattern = Dec.pattern
	returnType = Dec.returnType
	associativity = Dec.associativity
	precedence = Dec.precedence
	contextualize = Dec.contextualize
	inlineDefinition _ = Nothing
	resolve bindings declaration = do
		let parameterizedReturnType = case resolveOrBaseType bindings declaration.returnType of
				SomeConcreteThing thing -> Thing.parameterize thing
		let resolvedDeclaration = declaration {
				Dec.returnType = parameterizedReturnType }
		SomeOperator resolvedDeclaration
	hasProp test declaration = do
		let propsContext = C.fromThings [SomeThing test.current.candidate]
		let namedCandidate = do
				candidateType <- Thing.castThing (SomeThing test.current.candidate) ::
					Maybe SomeParameterizedThing
				case candidateType of
					SomeParameterizedThing thing ->
						cast thing :: Maybe (NamedThing SomeParameterizedThing)
		let exactNamedOne argType = do
				namedArgType <- case argType of
					SomeParameterizedThing thing ->
						cast thing :: Maybe (NamedThing SomeParameterizedThing)
				candidateType <- namedCandidate
				return $ namedArgType.name == candidateType.name
		let satisfiesOne candidateOp = case OMap.lookup "One" $ Pattern.getArgs $ Ops.pattern candidateOp of
			Nothing -> True
			Just Argument{argType} -> case exactNamedOne argType of
				Just isExact -> isExact
				Nothing -> case (test, test.current.candidate) `satisfiesDuring` argType of
					Falue _ -> True
					Error _ -> False
		let outerContext = Context.Context {
			precedence = test.context.precedence,
			deck = filter satisfiesOne test.context.deck }
		let propsTest = debug "Restricting declaration prop lookup to candidate props"
			test { Test.context = propsContext }
		let outerTest = debug "Restricting declaration prop lookup to applicable outer props"
			test { Test.context = outerContext }
		case C.has propsTest (SomeOperator declaration) of
			Falue _ -> do
				debugM $ "SATISFIED declaration prop: " ++ show declaration
				Falue test
			Error e1 -> case C.has outerTest (SomeOperator declaration) of
				Falue _ -> do
					debugM $ "SATISFIED declaration prop in outer context: " ++ show declaration
					Falue test
				Error e2 -> do
					let unsatisfiedError =
							UnsatisfiedProperty (SomeOperator declaration) $ e1 <!> e2
					debugM $ "UNSATISFIED declaration prop: " ++ show unsatisfiedError
					Error unsatisfiedError
	runUsing invocation@Invocation{operator = declaration, ..} = do
		let args = OMap.toMap $ OMap.map (\argument -> argument.value) $ Match.getArgs match
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
	resolve bindings definition = do
		let parameterizedReturnType = case
				resolveOrBaseType bindings definition.declaration.returnType of
			SomeConcreteThing thing -> Thing.parameterize thing
		let resolvedDeclaration = definition.declaration {
				Dec.returnType = parameterizedReturnType }
		let resolvedDefinition = definition { declaration = resolvedDeclaration }
		SomeOperator resolvedDefinition
	hasProp test definition = do
		let prop = SomeOperator definition
		let propsContext = C.fromThings [SomeThing test.current.candidate]
		let propTest = do
			debug "Restricting test context to props for definition prop"
				test { Test.context = propsContext }
		let onlyOneArg op = OMap.keys (Pattern.getArgs $ Ops.pattern op) == ["One"]
		let samePropDefinition candidate = case Ops.inlineDefinition candidate of
			Nothing -> Nothing
			Just candidateDefinition -> do
				let compareTest = TypeTest {
						context = test.context,
						ongoing = test.ongoing,
						current = test.current,
						candidateParameterMatches = Map.empty,
						requirementParameterMatches = Map.empty }
				case (compareTest, SomeOperator candidateDefinition) `satisfies` definition of
					Falue _ -> Just candidateDefinition
					Error _ -> Nothing
		let matchingDefinition = do
			matchingOp <- find (isJust . samePropDefinition) propsContext.deck
			samePropDefinition matchingOp
		let mismatchedBitValue = do
			guard $ onlyOneArg definition
			matchingDefinition' <- matchingDefinition
			guard $ onlyOneArg matchingDefinition'
			NativeBitsType{size = 1} <- case Thing.normalize $ Ops.returnType definition of
				SomeThing normalizedReturn -> cast normalizedReturn
			let args = Map.singleton "One" $ SomeThing test.current.candidate
			requirementValue <- case Def.runWith definition args of
				Falue value -> Just value
				Error _ -> Nothing
			candidateValue <- case Def.runWith matchingDefinition' args of
				Falue value -> Just value
				Error _ -> Nothing
			if candidateValue == requirementValue then
				Nothing
			else
				Just (candidateValue, requirementValue)

		case mismatchedBitValue of
			Just (candidateValue, requirementValue) -> do
				let obscureError = ObscuredProperty prop $ ReturnTypeMismatch $
						PrimitiveMismatch candidateValue requirementValue
				debugM $ "UNSATISFIED prop due to mismatched bit value: " ++ show obscureError
				Error obscureError
			Nothing -> case C.has propTest prop of
				Falue _ -> do
					debugM $ "SATISFIED definition prop: " ++ show definition
					Falue test
				Error e -> if isReturnTypeMismatch e then do
					let obscureError = ObscuredProperty prop e
					debugM $ "UNSATISFIED prop due to obscuring: " ++ show obscureError
					Error obscureError
				else do
					debugM $ "SATISFIED definition prop by itself (no match in context, " ++
						"but no obscuring operator): " ++ show definition
					Falue test
	runUsing Invocation{operator = definition, match} = Def.runWith definition $
		OMap.toMap $ OMap.map (\argument -> argument.value) $ Match.getArgs match

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
	resolve bindings (SomeOperator op) = Ops.resolve bindings op
	runUsing Invocation{operator = SomeOperator op, context, match, location, returnType} =
		Ops.runUsing Invocation{operator = op, context, match, location, returnType}

instance HasField "location" SomeOperator Location where
	getField (SomeOperator op) = Ops.location op

instance HasField "decLoc" SomeOperator Location where
	getField (SomeOperator op) = Ops.decLoc op

instance HasField "pattern" SomeOperator SomePattern where
	getField (SomeOperator op) = Ops.pattern op

instance HasField "returnType" SomeOperator SomeParameterizedThing where
	getField (SomeOperator op) = Ops.returnType op

instance HasField "associativity" SomeOperator Associativity where
	getField (SomeOperator op) = Ops.associativity op

instance HasField "precedence" SomeOperator PrecedenceBound where
	getField (SomeOperator op) = Ops.precedence op

instance HasField "contextualize" SomeOperator ArgContextBuilder where
	getField (SomeOperator op) = Ops.contextualize op

instance Eq SomeOperator where
	op1 == op2 =
		op1.location == op2.location &&
		op1.decLoc == op2.decLoc &&
		isDefinition op1 == isDefinition op2

instance Show SomeOperator where
	show (SomeOperator op) = "op(" ++ show op ++ ")"

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

satisfies ::
	(Operator candidate, Operator requirement) =>
	(TypeTest, candidate) ->
	requirement ->
	FallibleI Dec.Mismatch TypeTest
satisfies (test, candidate) requirement = do
	debugM $ "Testing satisfaction of operator:\n" ++
		"\tCandidate: " ++ show candidate ++ "\n\tRequirement: " ++ show requirement
	if Ops.decLoc candidate == Ops.decLoc requirement then do
		debugM $ "Satisfies because the operators have equal declarations"
		Falue test
	else do
		let patternResult = mapError PatternMismatch $
			(test, Ops.pattern candidate) `Pattern.satisfies` Ops.pattern requirement
		case patternResult of
			Falue patternTest -> do
				debugM $ "Satisfied PATTERN of operator:\n\t✓ Candidate" ++
					show (Ops.pattern candidate) ++
					"\n\t✓ Requirement: " ++ show (Ops.pattern requirement) ++
						"\nComparing return types next:\n\t? Candidate:" ++
							show (Ops.returnType candidate) ++
						"\n\t? Requirement: "
				let resolvedCandidateReturnTypeConcrete =
						resolveOrBaseType patternTest.requirementParameterMatches $
							Ops.returnType candidate
				let resolvedRequirementReturnTypeConcrete =
						resolveOrBaseType patternTest.candidateParameterMatches $
							Ops.returnType requirement
				let asSomeThing concrete = case concrete of
						SomeConcreteThing thing -> SomeThing thing
				let asParameterized concrete = case concrete of
						SomeConcreteThing thing -> Thing.parameterize thing
				let shownConcrete concrete = case concrete of
						SomeConcreteThing thing -> show thing
				let returnTypeResult = if
						asSomeThing resolvedCandidateReturnTypeConcrete ==
							asSomeThing resolvedRequirementReturnTypeConcrete then
						Falue patternTest
					else
						mapError ReturnTypeMismatch $
							(patternTest, asParameterized resolvedCandidateReturnTypeConcrete)
								`satisfiesDuring`
									Thing.parameterize resolvedRequirementReturnTypeConcrete
				case returnTypeResult of
					Falue _ -> debugM $ "SATISFIED operator:\n\t✓ Candidate:" ++
						shownConcrete resolvedCandidateReturnTypeConcrete ++
						"\n\t✓ Requirement: " ++ shownConcrete resolvedRequirementReturnTypeConcrete
					Error returnTypeError -> debugM $
						"UNsatisfied RETURN TYPE of operator:\n\t╳ Candidate:" ++
						shownConcrete resolvedCandidateReturnTypeConcrete ++
						"\n\t╳ Requirement: " ++ shownConcrete resolvedRequirementReturnTypeConcrete ++
						"\n\tReason: " ++ show returnTypeError
				returnTypeResult
			Error patternError -> do
				debugM $ "UNSATISFIED operator by pattern mismatch:\n\t╳ Candidate: " ++
					show (Ops.pattern candidate) ++
					"\n\t╳ Requirement: " ++ show (Ops.pattern requirement) ++
					"\n\tReason: " ++ show patternError
				Error patternError

filterDefs :: [SomeOperator] -> [Definition]
filterDefs = catMaybes . map maybeDefinition
	where
		maybeDefinition :: SomeOperator -> Maybe Definition
		maybeDefinition (SomeOperator op) = Ops.inlineDefinition op

isDefinition :: SomeOperator -> Bool
isDefinition (SomeOperator op) = isJust $ Ops.inlineDefinition op
