module Beng.Things (
	thing,
	undefined,
	propsOf,
	defsOf,
	satisfiesThing,
	module Beng.Types.Things
) where

import Prelude hiding (undefined)

import Control.Monad (join)
import Utils.Fallible hiding (fromMaybe)
import Utils.Lists (equalsIgnoreOrder, showWithAnd, showWithOr, wrap)
import Utils.Messaging (Messagable, msg, msgList)
import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2
import Utils.Strings (aOrAn, parenthesize)
import Utils.Tuples (mapFst2, toList2)

import {-# SOURCE #-} qualified Beng.Build.TypeTest as Test
import {-# SOURCE #-} Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import Beng.Invocations ()
import {-# SOURCE #-} Beng.Parse.Patterns ()
import qualified Beng.Invocations as Inv
import Beng.Operators (filterDefs)
import qualified Beng.Types.Operators as Ops
import Beng.Types.Build.Context (Context)
import Beng.Types.Build.TypeTest (
	TypeTest(..),
	TypeTestProgressResult,
	TypeTestResult )
import qualified Beng.Types.Build.TypeTest as TestType
import qualified Beng.Types.Things as Thing
import Beng.Types.Invocations (SomeInvocation)
import Beng.Types.Operators (SomeOperator(..))
import qualified Beng.Types.Operators.Declarations as Dec
import Beng.Types.Operators.Declarations (Declaration)
import Beng.Types.Operators.Definitions (Definition(..))
import Beng.Types.Operators.Declarations (Declaration(..))
import Beng.Types.Parse.Patterns (
	SomePattern(..) )
import Beng.Types.Things (
	Mismatch(..),
	Undefined(..),
	ResolveError(..),
	Binding(Binding),
	Thing,
	ConcreteThing,
	ParameterizedThing,
	SomeThing(..),
	SomeConcreteThing(..),
	SomeParameterizedThing(..),
	OpType(..),
	DefinitionType(..),
	DeclarationType(..),
	PatternType(..),
	Parameter(..),
	ParameterMatches,
	PreOpType(..),
	NativeBitsValue(..),
	NativeCharValue(..),
	NativeStringValue(..),
	NativeListValue(..),
	NativeSomeValue(..),
	NativeOptionalValue(..),
	NativeType(..),
	NativeBitsType(..),
	NativeCharType(..),
	NativeStringType(..),
	NativeListType(..),
	NativeSomeType(..),
	NativeOptionalType(..),
	NativeOrType(..),
	One(..),
	CombinedThings(..),
	NamedThing(..) )
import qualified Beng.Types.Things as Mismatch

import qualified Data.ByteString as BS
import Data.List (intercalate, nub)
import Data.List.Extra (takeEnd)
import Data.Map (Map, assocs)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text.Lazy (pack)
import qualified Data.Text.Lazy as Text
import Data.Typeable (cast)
import Numeric (showHex)

thing :: SomeThing
thing = SomeThing $ NativeType $ const []

showArg :: String -> String -> String
showArg name typeString = "'" ++ name ++ ", " ++ aOrAn typeString ++ "'"

showArgsUsing :: (SomeThing -> String) -> Map String SomeThing -> String
showArgsUsing showT = showWithAnd . map (\(key, argType) -> showArg key $ showT argType) . assocs

showThingUsing :: (Show a, Messagable a) => Bool -> a -> String
showThingUsing useMsg =
	if useMsg then
		msg
	else
		show

showMismatchUsing :: Bool -> Mismatch -> String
showMismatchUsing useMsg mismatch = do
	let showThing = showThingUsing useMsg
	let showMismatch = showMismatchUsing useMsg
	case mismatch of
		MismatchedArgument{..} ->
			"'" ++ name ++ "' was expected to be " ++ showThing requirement ++
				", but it was " ++ showThing candidate ++ "!"
		MissingArgument{..} ->
			showArg name (showThing requirement) ++ " was not found in " ++
				showArgsUsing showThing candidateArgs
		ExtraArgument{..} ->
			showArg name (showThing candidate) ++ " was not expected; only " ++
				showArgsUsing showThing requirementArgs ++ " were!"
		UnsatisfiedProperty{..} ->
			"it did not satisfy " ++ show property ++ ": " ++ show decMismatch
		ObscuredProperty{..} ->
			"it obscured " ++ show property ++ ": " ++ show decMismatch
		UnsatisfiedParent{..} ->
			showThing candidate ++ " does not satisfy its parent, " ++ showThing parent ++ ": " ++
				showMismatch cause
		PrimitiveMismatch{..} ->
			showThing candidate ++ " does not satisfy " ++ showThing requirement ++ "!"
		Tautology{..} ->
			showThing candidate ++ " can only satisfy " ++ showThing requirement ++
				" tautologically!"
		CompoundMismatch{..} ->
			showCompoundErrorsUsing showMismatch context compound

propsWithSome :: SomeThing -> SomeThing -> [SomeOperator]
propsWithSome (SomeThing value) one = value `Thing.propsWith` one

asOpType :: (SomeThing -> Maybe OpType)
asOpType (SomeThing value) = cast value

asNativeListValue :: (SomeThing -> Maybe (NativeListValue SomeThing))
asNativeListValue (SomeThing value) = cast value

asNativeSomeValue :: (SomeThing -> Maybe (NativeSomeValue SomeThing))
asNativeSomeValue (SomeThing value) = cast value

asNativeBitsType :: (SomeThing -> Maybe NativeBitsType)
asNativeBitsType (SomeThing value) = cast value

asNativeBitsValue :: (SomeThing -> Maybe NativeBitsValue)
asNativeBitsValue (SomeThing value) = cast value

asNativeCharValue :: (SomeThing -> Maybe NativeCharValue)
asNativeCharValue (SomeThing value) = cast value

asNativeStringValue :: (SomeThing -> Maybe NativeStringValue)
asNativeStringValue (SomeThing value) = cast value

asNativeListTypeP :: (SomeThing -> Maybe (NativeListType SomeParameterizedThing))
asNativeListTypeP (SomeThing value) = cast value

asNativeSomeTypeP :: (SomeThing -> Maybe (NativeSomeType SomeParameterizedThing))
asNativeSomeTypeP (SomeThing value) = cast value

asNativeOptionalTypeP :: (SomeThing -> Maybe (NativeOptionalType SomeParameterizedThing))
asNativeOptionalTypeP (SomeThing value) = cast value

asNativeOptionalValue :: (SomeThing -> Maybe (NativeOptionalValue SomeThing))
asNativeOptionalValue (SomeThing value) = cast value

satisfiesProps ::
	(TypeTest, SomeThing) -> (SomeThing -> [SomeOperator]) -> TypeTestProgressResult
satisfiesProps (test, candidate) propsWith = case propsWith candidate of
	[] -> Falue test
	SomeOperator op:rest -> case Ops.hasProp test op of
		Error e -> Error e
		Falue nextTest -> satisfiesProps (nextTest, candidate) $ const rest

testBits ::
	TypeTest -> Int -> Int -> SomeThing -> SomeThing -> TypeTestProgressResult
testBits test candidateSize requirementSize candidate requirement =
	if candidateSize <= requirementSize then
		Falue test
	else
		Error $ PrimitiveMismatch candidate requirement

testListLike ::
	TypeTest ->
	SomeThing ->
	SomeThing ->
	[SomeThing] ->
	[SomeParameterizedThing] ->
	TypeTestProgressResult
testListLike test candidate requirement candidateElements requirementElements =
	if length candidateElements < length requirementElements then
		Error $ PrimitiveMismatch candidate requirement
	else
		testPairs test candidateElements requirementElements
	where
		testPairs nextTest nextCandidates nextRequirements = case nextRequirements of
			[] -> Falue nextTest
			requirementElement:requirementRest -> case nextCandidates of
				[] -> Error $ PrimitiveMismatch candidate requirement
				candidateElement:candidateRest -> case
						(nextTest, Thing.parameterize candidateElement)
							`Test.satisfiesDuring` requirementElement of
					Error e -> Error e
					Falue latestTest -> testPairs latestTest candidateRest requirementRest

testListLikeType :: TypeTest -> SomeParameterizedThing -> [SomeThing] -> TypeTestProgressResult
testListLikeType test elementType values =
	case values of
		[] -> Falue test
		value:rest -> case (test, Thing.parameterize value) `Test.satisfiesDuring` elementType of
			Error e -> Error e
			Falue nextTest -> testListLikeType nextTest elementType rest

satisfyAll :: TypeTest -> SomeThing -> [SomeParameterizedThing] -> TypeTestProgressResult
satisfyAll test _ [] = Falue test
satisfyAll test candidate (requirement:rest) = case
		(test, Thing.parameterize candidate) `Test.satisfiesDuring` requirement of
	Error e -> Error e
	Falue nextTest -> satisfyAll nextTest candidate rest

satisfyAny :: TypeTest -> SomeThing -> [SomeParameterizedThing] -> TypeTestProgressResult
satisfyAny test candidate requirements = case requirements of
	[] -> primitiveMismatch candidate $ SomeThing $ NativeType $ const []
	[requirement] -> (test, Thing.parameterize candidate) `Test.satisfiesDuring` requirement
	requirement:rest -> case
			(test, Thing.parameterize candidate) `Test.satisfiesDuring` requirement of
		Falue nextTest -> Falue nextTest
		Error e1 -> case satisfyAny test candidate rest of
			Error e2 -> Error $ e1 <!> e2
			Falue nextTest -> Falue nextTest

primitiveMismatch :: SomeThing -> SomeThing -> TypeTestProgressResult
primitiveMismatch candidate requirement = Error $ PrimitiveMismatch candidate requirement

normalizeParameterized :: Thing thing => (thing -> SomeParameterizedThing)
normalizeParameterized = Thing.parameterize . Thing.normalize

data ParameterMatchSide =
	CandidateParameterMatch |
	RequirementParameterMatch

parameterBindings :: TypeTest -> Parameter -> [Binding]
parameterBindings test parameter = do
	let bindingsIn :: ParameterMatches -> [Binding]
	    bindingsIn matches = case Map.lookup parameter matches of
			Just bindings -> bindings.l
			Nothing -> []
	bindingsIn test.candidateParameterMatches ++ bindingsIn test.requirementParameterMatches

checkParameterBindings ::
	Bool -> TypeTest -> SomeThing -> Parameter -> SomeParameterizedThing -> TypeTestProgressResult
checkParameterBindings checkCandidateBindings test candidate parameter requirement = do
	let checkBinding nextTest (Binding _ thing) =
			if checkCandidateBindings then
				(nextTest, Thing.parameterize $ SomeThing thing) `Test.satisfiesDuring` requirement
			else
				(nextTest, Thing.parameterize candidate)
					`Test.satisfiesDuring` Thing.parameterize thing
	foldl
		(\testResult binding ->
			join $ fmap (\nextTest -> checkBinding nextTest binding) testResult)
		(Falue test)
		(parameterBindings test parameter)

bindParameter :: ParameterMatchSide -> TypeTest -> Parameter -> SomeThing -> TypeTest
bindParameter side test parameter thing = do
	let addBinding = do
			let wrappedThing = Thing.parameterize thing
			let newBinding = Binding parameter.decLoc wrappedThing
			let addOrUpdate matches = case Map.lookup parameter matches of
					Nothing -> Map.insert parameter (P.singleton newBinding) matches
					Just bindings -> if any
						(\(Binding _ boundThing) ->
							wrappedThing == boundThing)
						bindings.l then
						matches
					else
						Map.insert parameter (P.cons newBinding bindings) matches
			case side of
				CandidateParameterMatch -> test{
					candidateParameterMatches =
						addOrUpdate test.candidateParameterMatches }
				RequirementParameterMatch -> test{
					requirementParameterMatches =
						addOrUpdate test.requirementParameterMatches }
	case Thing.asParameter thing of
		Just boundParameter ->
			if boundParameter == parameter then
				test
			else
				addBinding
		Nothing ->
			addBinding

combineConcreteThings :: [SomeConcreteThing] -> SomeConcreteThing
combineConcreteThings things = case nub things of
	[] -> SomeConcreteThing $ NativeType $ const []
	[oneThing] -> oneThing
	firstThing:secondThing:restThings ->
		SomeConcreteThing $ CombinedThings $ P2.Populace2 firstThing secondThing restThings

continueCurrentWith :: TypeTest -> SomeParameterizedThing -> TypeTestProgressResult
continueCurrentWith test requirement = Test.runTestProgress test {
	current = test.current { TestType.requirement } }

argKeysOf :: Map String a -> Map String b -> Set String
argKeysOf candidateArgs requirementArgs =
	Set.union (Set.fromList $ Map.keys candidateArgs) (Set.fromList $ Map.keys requirementArgs)

instance Eq SomeThing where
	SomeThing (left :: l) == SomeThing right =
		case (Thing.normalize left, Thing.normalize right) of
			(SomeThing (leftThing :: l2), SomeThing rightThing) -> case cast rightThing of
				Just rightEq -> leftThing == rightEq
				Nothing -> False

instance Show SomeThing where
	show (SomeThing value) = "thing(" ++ show value ++ ")"

instance Messagable SomeThing where
	msg (SomeThing value) = msg value

deriving instance Eq Mismatch

instance Show Mismatch where
	show = showMismatchUsing False

instance Messagable Mismatch where
	msg = showMismatchUsing True

instance Ord Mismatch where
	compare CompoundMismatch{..} mismatch = compare compound.head mismatch
	compare mismatch CompoundMismatch{..} = compare mismatch compound.head
	compare mismatch1 mismatch2 = compare (typeIndex mismatch1) (typeIndex mismatch2)
		where
			typeIndex = \case
				MismatchedArgument{} -> 1
				MissingArgument{} -> 2
				ExtraArgument{} -> 3
				UnsatisfiedProperty{} -> 4
				ObscuredProperty{} -> 5
				UnsatisfiedParent{} -> 6
				PrimitiveMismatch{} -> 7
				Tautology{} -> 8
				CompoundMismatch{} -> 9

instance IsError Mismatch where
	prepend newContext = \case
		compoundMismatch@CompoundMismatch{} ->
			compoundMismatch { Mismatch.context = newContext ++ compoundMismatch.context }
		mismatch -> CompoundMismatch { context = newContext, compound = P.singleton mismatch }
	(<!>) mismatch1 mismatch2 = do
		let getCompound mismatch = case mismatch of
				CompoundMismatch{..} -> Just (context, compound)
				_ -> Nothing
		compoundErrorsUsing getCompound CompoundMismatch mismatch1 mismatch2

deriving instance Eq Undefined

instance Show Undefined where
	show Undefined{decsByContext} = intercalate "\n" $
		map (\(context, declaration) -> context ++ show declaration ++ " :/=") decsByContext

instance Messagable Undefined where
	msg = show

instance IsError Undefined where
	prepend context Undefined{decsByContext} =
		Undefined $ map (mapFst2 (context ++)) decsByContext
	(<!>) undefined1 undefined2 = Undefined $ undefined1.decsByContext ++ undefined2.decsByContext

instance Eq ResolveError where
	left == right = compare left right == EQ

instance Show ResolveError where
	show = \case
		MissingParameter{parameter, availableMatches} ->
			"Missing parameter binding for " ++ show parameter ++
				" with available matches " ++ show availableMatches
		CompoundResolveError{contexts, compound} ->
			showCompoundErrorsUsing show (concat contexts) compound

instance Messagable ResolveError where
	msg = show

instance Ord ResolveError where
	compare left right = case (left, right) of
		(left@CompoundResolveError{}, right) -> compare left.compound.head right
		(left, right@CompoundResolveError{}) -> compare left right.compound.head
		(MissingParameter{parameter = leftParameter}, MissingParameter{parameter = rightParameter}) ->
			compare leftParameter rightParameter

instance IsError ResolveError where
	prepend context = \case
		resolveError@CompoundResolveError{} -> resolveError {
			contexts = case resolveError.contexts of
				[] -> [context]
				contexts -> map (context ++) contexts }
		resolveError -> CompoundResolveError {
			contexts = [context],
			compound = P.singleton resolveError }
	(<!>) left right = if compare left right == EQ then
			case (left, right) of
				(left@CompoundResolveError{}, right@CompoundResolveError{}) | left.compound == right.compound ->
					CompoundResolveError (nub $ left.contexts <> right.contexts) left.compound
				(left@CompoundResolveError{}, right@CompoundResolveError{}) | left.contexts == right.contexts ->
					CompoundResolveError left.contexts $ left.compound <> right.compound
				(left@CompoundResolveError{}, right) | null left.contexts ->
					CompoundResolveError [] $ P.snoc left.compound right
				(left, right@CompoundResolveError{}) | null right.contexts ->
					CompoundResolveError [] $ P.cons left right.compound
				(left, right) ->
					CompoundResolveError [] $ P.Populace left [right]
		else
			min left right

instance Eq NativeType where
	(==) nativeType1 nativeType2 =
		nativeType1.properties (SomeThing One) `equalsIgnoreOrder`
			nativeType2.properties (SomeThing One)

deriving instance Eq OpType
deriving instance Eq DefinitionType
deriving instance Eq DeclarationType
deriving instance Eq PatternType
deriving instance Eq thing => Eq (PreOpType thing)
deriving instance Eq NativeBitsValue
deriving instance Eq NativeCharValue
deriving instance Eq NativeStringValue
deriving instance Eq thing => Eq (NativeListValue thing)
deriving instance Eq thing => Eq (NativeSomeValue thing)
deriving instance Eq thing => Eq (NativeOptionalValue thing)
deriving instance Eq NativeBitsType
deriving instance Eq NativeCharType
deriving instance Eq NativeStringType
deriving instance Eq thing => Eq (NativeListType thing)
deriving instance Eq thing => Eq (NativeSomeType thing)
deriving instance Eq thing => Eq (NativeOptionalType thing)
deriving instance Eq thing => Eq (NativeOrType thing)
deriving instance Eq One
deriving instance Eq thing => Eq (CombinedThings thing)
deriving instance Eq thing => Eq (NamedThing thing)
deriving instance Eq Binding
deriving instance Show Binding

instance Show OpType where
	show OpType{args, returnType} =
		if null args then
			show returnType ++ " op"
		else do
			let argToString argName argType = argName ++ ", a(n) " ++ show argType
			let argStrings = map (uncurry argToString) $ assocs args
			showWithAnd argStrings ++ " => " ++ show returnType

instance Show DefinitionType where
	show DefinitionType = "op definition"

instance Show DeclarationType where
	show DeclarationType = "op declaration"

instance Show PatternType where
	show PatternType = "op pattern"

instance Show Parameter where
	show Parameter{name, baseType} = name ++ " :: " ++ show baseType

instance Show thing => Show (PreOpType thing) where
	show PreOpType{resolvedType} = "a preop of " ++ show resolvedType

instance Show NativeBitsValue where
	show NativeBitsValue{bytes} =
		"0x" ++ concatMap (\byte -> takeEnd 2 $ '0' : showHex byte "") (BS.unpack bytes)

instance Show NativeCharValue where
	show NativeCharValue{char} = wrap "'" [char]

instance Show NativeStringValue where
	show NativeStringValue{text} = show text

instance Show thing => Show (NativeListValue thing) where
	show NativeListValue{values} = show values

instance Show thing => Show (NativeSomeValue thing) where
	show NativeSomeValue{valuesP} = show valuesP

instance Show thing => Show (NativeOptionalValue thing) where
	show NativeOptionalValue{fal} = show fal

instance Show NativeType where
	show NativeType{properties} =
		if null $ properties (SomeThing One) then
			"thing"
		else
			showWithAnd $ properties (SomeThing One)

instance Show NativeBitsType where
	show NativeBitsType{size=1} = "a bit"
	show NativeBitsType{size} = show size ++ " bits"

instance Show NativeCharType where
	show NativeCharType = "a native char"

instance Show NativeStringType where
	show NativeStringType = "a native string"

instance Thing thing => Show (NativeListType thing) where
	show NativeListType{elementType} = "a native list of " ++ show elementType

instance Thing thing => Show (NativeSomeType thing) where
	show NativeSomeType{elementType} = "a native some " ++ show elementType

instance Thing thing => Show (NativeOptionalType thing) where
	show NativeOptionalType{falueType} = "a native " ++ show falueType ++ "?"

instance Thing thing => Show (NativeOrType thing) where
	show NativeOrType{options} = "a native " ++ showWithOr options.l

instance Show One where
	show One = "one"

instance Show thing => Show (CombinedThings thing) where
	show CombinedThings{things} = intercalate " + " $ map show things.l

instance Show thing => Show (NamedThing thing) where
	show NamedThing{name, value} = parenthesize $ name ++ " := " ++ show value

instance Messagable OpType where
	msg = show

instance Messagable DefinitionType where
	msg = show

instance Messagable DeclarationType where
	msg = show

instance Messagable PatternType where
	msg = show

instance Messagable Parameter where
	msg Parameter{name} = name

instance Messagable thing => Messagable (PreOpType thing) where
	msg PreOpType{resolvedType} = "a preop of " ++ msg resolvedType

instance Messagable NativeBitsValue where
	msg = show

instance Messagable NativeCharValue where
	msg NativeCharValue{char} = wrap "'" [char]

instance Messagable NativeStringValue where
	msg NativeStringValue{text} = msg text

instance Messagable thing => Messagable (NativeListValue thing) where
	msg NativeListValue{values} = msgList values

instance Messagable thing => Messagable (NativeSomeValue thing) where
	msg NativeSomeValue{valuesP} = msg valuesP

instance (Show thing, Messagable thing) => Messagable (NativeOptionalValue thing) where
	msg NativeOptionalValue{fal} = fallible ((++"!") . show) show fal

instance Messagable NativeType where
	msg NativeType{properties} =
		if null $ properties (SomeThing One) then
			"thing"
		else
			msgList $ properties (SomeThing One)

instance Messagable NativeBitsType where
	msg = show

instance Messagable NativeCharType where
	msg NativeCharType = "a char"

instance Messagable NativeStringType where
	msg NativeStringType = "a string"

instance Thing thing => Messagable (NativeListType thing) where
	msg NativeListType{elementType} = "a list of " ++ msg elementType

instance Thing thing => Messagable (NativeSomeType thing) where
	msg NativeSomeType{elementType} = "some " ++ msg elementType

instance Thing thing => Messagable (NativeOptionalType thing) where
	msg NativeOptionalType{falueType} = msg falueType ++ "?"

instance Thing thing => Messagable (NativeOrType thing) where
	msg NativeOrType{options} = showWithOr $ map msg options.l

instance Messagable One where
	msg = show

instance Messagable thing => Messagable (CombinedThings thing) where
	msg CombinedThings{things} = intercalate " + " $ map msg things.l

instance Messagable thing => Messagable (NamedThing thing) where
	msg NamedThing{name} = name

instance Thing SomeThing where
	toCode (SomeThing thing) = Thing.toCode thing
	propsWith (SomeThing thing) = Thing.propsWith thing
	normalize (SomeThing thing) = Thing.normalize thing
	parameterize (SomeThing thing) = Thing.parameterize thing
	asParameter (SomeThing thing) = Thing.asParameter thing
	satisfiesAsCandidate test (SomeThing thing) requirement =
		Thing.satisfiesAsCandidate test thing requirement

instance Eq SomeConcreteThing where
	SomeConcreteThing left == SomeConcreteThing right = Thing.normalize left == Thing.normalize right

instance Show SomeConcreteThing where
	show (SomeConcreteThing thing) = "concrete(" ++ show thing ++ ")"

instance Messagable SomeConcreteThing where
	msg (SomeConcreteThing thing) = msg thing

instance Thing SomeConcreteThing where
	toCode (SomeConcreteThing thing) = Thing.toCode thing
	propsWith (SomeConcreteThing thing) = Thing.propsWith thing
	normalize (SomeConcreteThing thing) = Thing.normalize thing
	parameterize (SomeConcreteThing thing) = Thing.parameterize thing
	asParameter (SomeConcreteThing thing) = Thing.asParameter thing
	satisfiesAsCandidate test (SomeConcreteThing thing) requirement =
		Thing.satisfiesAsCandidate test thing requirement

instance ConcreteThing SomeConcreteThing

instance Eq SomeParameterizedThing where
	SomeParameterizedThing left == SomeParameterizedThing right = Thing.normalize left == Thing.normalize right

instance Show SomeParameterizedThing where
	show (SomeParameterizedThing thing) = "params(" ++ show thing ++ ")"

instance Messagable SomeParameterizedThing where
	msg (SomeParameterizedThing thing) = msg thing

instance Thing SomeParameterizedThing where
	toCode (SomeParameterizedThing thing) = Thing.toCode thing
	propsWith (SomeParameterizedThing thing) = Thing.propsWith thing
	normalize (SomeParameterizedThing thing) = Thing.normalize thing
	parameterize = id
	asParameter (SomeParameterizedThing thing) = Thing.asParameter thing
	satisfiesAsCandidate test (SomeParameterizedThing thing) requirement =
		Thing.satisfiesAsCandidate test thing requirement

instance ParameterizedThing SomeParameterizedThing where
	satisfies (test, candidate) (SomeParameterizedThing thing) =
		Thing.satisfies (test, candidate) thing
	resolve bindings (SomeParameterizedThing thing) = Thing.resolve bindings thing

instance Thing SomeInvocation where
	toCode = Inv.toCode
	parameterize = SomeParameterizedThing

instance ConcreteThing SomeInvocation

instance ParameterizedThing SomeInvocation where
	resolve _ invocation = return $ SomeConcreteThing invocation

instance Thing Definition where
	propsWith definition _ = [SomeOperator definition]
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing Definition

instance ParameterizedThing Definition where
	resolve bindings definition = do
		resolvedReturnType <- Thing.resolve bindings definition.declaration.returnType
		return $ SomeConcreteThing definition {
			declaration = definition.declaration {
				Dec.returnType = Thing.parameterize resolvedReturnType } }

instance Thing Declaration where
	propsWith declaration _ = [SomeOperator declaration]
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing Declaration

instance ParameterizedThing Declaration where
	resolve bindings declaration = do
		resolvedReturnType <- Thing.resolve bindings declaration.returnType
		return $ SomeConcreteThing declaration {
			Dec.returnType = Thing.parameterize resolvedReturnType }

instance Thing SomePattern where
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing SomePattern

instance ParameterizedThing SomePattern where
	resolve _ pattern = return $ SomeConcreteThing pattern

instance Thing OpType where
	toCode = pack . show
	normalize OpType{args, returnType} =
		SomeThing $ OpType {
			args = fmap normalizeParameterized args,
			returnType = normalizeParameterized returnType }
	parameterize = SomeParameterizedThing

instance ConcreteThing OpType

instance ParameterizedThing OpType where
	satisfies (test, candidate) requirement = case asOpType candidate of
		Just candidateType -> do
			returnTypeTest <- (test, Thing.parameterize candidateType.returnType)
				`Test.satisfiesDuring`
				requirement.returnType
			testArgs returnTypeTest $ Set.elems $ argKeysOf candidateType.args requirement.args
			where
				testArgs nextTest keys = case keys of
					[] -> Falue nextTest
					key:rest -> case (candidateType.args Map.!? key, requirement.args Map.!? key) of
						(Nothing, Nothing) ->
							primitiveMismatch candidate $ SomeThing requirement
						(Just candidateArgType, Nothing) ->
							Error $ ExtraArgument key (SomeThing candidateArgType) $
								Map.map SomeThing requirement.args
						(Nothing, Just requirementArgType) ->
							Error $ MissingArgument key (SomeThing requirementArgType) $
								Map.map SomeThing candidateType.args
						(Just candidateArgType, Just requirementArgType) ->
							case mapError
								(MismatchedArgument key (SomeThing candidateArgType)
									(SomeThing requirementArgType))
								$ (nextTest, Thing.parameterize candidateArgType)
									`Test.satisfiesDuring` requirementArgType of
								Error e -> Error e
								Falue latestTest -> testArgs latestTest rest
		Nothing -> Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve bindings requirement = do
		resolvedArgs <- traverse (fmap Thing.parameterize . Thing.resolve bindings) requirement.args
		resolvedReturnType <- Thing.resolve bindings requirement.returnType
		return $ SomeConcreteThing $ OpType {
			args = resolvedArgs,
			returnType = Thing.parameterize resolvedReturnType }

instance Thing DefinitionType where
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing DefinitionType

instance ParameterizedThing DefinitionType where
	resolve _ definitionType = return $ SomeConcreteThing definitionType

instance Thing DeclarationType where
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing DeclarationType

instance ParameterizedThing DeclarationType where
	resolve _ declarationType = return $ SomeConcreteThing declarationType

instance Thing PatternType where
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing PatternType

instance Thing Parameter where
	toCode Parameter{name} = pack name
	parameterize = SomeParameterizedThing
	asParameter = Just
	satisfiesAsCandidate test parameter requirement = Just do
		baseTypeTest <- (test, Thing.parameterize $ SomeThing requirement)
			`Test.satisfiesDuring` parameter.baseType
		bindingsTest <- checkParameterBindings True baseTypeTest
			(SomeThing requirement) parameter requirement
		Falue $ bindParameter CandidateParameterMatch bindingsTest parameter $
			SomeThing requirement

instance ParameterizedThing Parameter where
	satisfies (test, candidate) requirement = do
		baseTypeTest <- (test, Thing.parameterize candidate)
			`Test.satisfiesDuring` requirement.baseType
		bindingsTest <- checkParameterBindings False baseTypeTest candidate requirement $
			Thing.parameterize requirement
		Falue $ bindParameter RequirementParameterMatch bindingsTest requirement candidate
	resolve bindings parameter = case Map.lookup parameter bindings of
		Just parameterBindings -> do
			let resolveBinding Binding{location, thing} = do
					resolvedThing <- Thing.resolve bindings thing
					return (location, resolvedThing)
			resolvedBindings <- traverse resolveBinding parameterBindings
			return $ combineConcreteThings $ map snd resolvedBindings.l
		Nothing ->
			Error $ MissingParameter { parameter, availableMatches = bindings }

instance ParameterizedThing PatternType where
	resolve _ patternType = return $ SomeConcreteThing patternType

instance Thing thing => Thing (PreOpType thing) where
	toCode = pack . show
	normalize PreOpType{resolvedType} =
		SomeThing $ PreOpType $ Thing.normalize resolvedType
	parameterize = SomeParameterizedThing

instance Thing thing => ParameterizedThing (PreOpType thing) where
	resolve _ preOpType = return $ SomeConcreteThing preOpType

instance Thing thing => ConcreteThing (PreOpType thing)

instance Thing NativeBitsValue where
	toCode NativeBitsValue{bytes} = pack $ show bytes
	parameterize = SomeParameterizedThing

instance ParameterizedThing NativeBitsValue where
	resolve _ nativeBitsValue = return $ SomeConcreteThing nativeBitsValue

instance ConcreteThing NativeBitsValue

instance Thing NativeCharValue where
	toCode NativeCharValue{char} = pack ['\'', char, '\'']
	parameterize = SomeParameterizedThing

instance ParameterizedThing NativeCharValue where
	resolve _ nativeCharValue = return $ SomeConcreteThing nativeCharValue

instance ConcreteThing NativeCharValue

instance Thing NativeStringValue where
	toCode NativeStringValue{text} = Text.concat ["\"", text, "\""]
	parameterize = SomeParameterizedThing

instance ParameterizedThing NativeStringValue where
	resolve _ nativeStringValue = return $ SomeConcreteThing nativeStringValue

instance ConcreteThing NativeStringValue

instance Thing thing => Thing (NativeListValue thing) where
	toCode NativeListValue{values} = case values of
		[] -> "[]"
		[solo] -> Thing.toCode solo
		[first, second] -> Text.concat [Thing.toCode first, " and ", Thing.toCode second]
		many -> Text.concat $
			(concatMap toList2 $ zip (map Thing.toCode $ init many) (repeat ", ")) ++
			["and ", Thing.toCode $ last many]
	normalize NativeListValue{values} =
		SomeThing $ NativeListValue $ map Thing.normalize values
	parameterize NativeListValue{values} =
		SomeParameterizedThing $ NativeListValue $ map Thing.parameterize values

instance ConcreteThing (NativeListValue SomeConcreteThing)

instance ParameterizedThing (NativeListValue SomeParameterizedThing) where
	satisfies (test, candidate) requirement = case asNativeListValue candidate of
		Just candidateValue ->
			testListLike test candidate (SomeThing requirement) candidateValue.values requirement.values
		Nothing -> case asNativeSomeValue candidate of
			Just candidateValue ->
				testListLike test candidate (SomeThing requirement) candidateValue.valuesP.l
					requirement.values
			Nothing -> Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve bindings requirement = do
		resolvedValues <- traverse (Thing.resolve bindings) requirement.values
		return $ SomeConcreteThing $ NativeListValue { values = resolvedValues }

instance Thing thing => Thing (NativeSomeValue thing) where
	toCode NativeSomeValue{valuesP} = Thing.toCode $ SomeThing $ NativeListValue valuesP.l
	normalize NativeSomeValue{valuesP} =
		SomeThing $ NativeSomeValue $ fmap Thing.normalize valuesP
	parameterize NativeSomeValue{valuesP} =
		SomeParameterizedThing $ NativeSomeValue $ fmap Thing.parameterize valuesP

instance ConcreteThing (NativeSomeValue SomeConcreteThing)

instance ParameterizedThing (NativeSomeValue SomeParameterizedThing) where
	satisfies (test, candidate) requirement = case asNativeSomeValue candidate of
		Just candidateValue ->
			testListLike test candidate (SomeThing requirement) candidateValue.valuesP.l
				(P.toList requirement.valuesP)
		Nothing -> case asNativeListValue candidate of
			Just candidateValue ->
				testListLike test candidate (SomeThing requirement) candidateValue.values
					(P.toList requirement.valuesP)
			Nothing -> Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve bindings requirement = do
		resolvedValues <- traverse (Thing.resolve bindings) requirement.valuesP
		return $ SomeConcreteThing $ NativeSomeValue { valuesP = resolvedValues }

instance Thing thing => Thing (NativeOptionalValue thing) where
	toCode NativeOptionalValue{fal} = case fal of
		Falue falue -> Thing.toCode falue
		Error error -> Text.concat ["\"", pack $ msg error, "\"!"]
	normalize NativeOptionalValue{fal} =
		SomeThing $ NativeOptionalValue $ fmap Thing.normalize fal
	parameterize NativeOptionalValue{fal} =
		SomeParameterizedThing $ NativeOptionalValue $ fmap Thing.parameterize fal

instance Thing thing => ParameterizedThing (NativeOptionalValue thing) where
	resolve _ nativeOptionalValue = return $ SomeConcreteThing nativeOptionalValue

instance Thing thing => ConcreteThing (NativeOptionalValue thing)

instance Thing NativeType where
	propsWith = properties
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing NativeType

instance ParameterizedThing NativeType where
	satisfies (test, candidate) requirement =
		(test, candidate) `satisfiesProps` requirement.properties
	resolve bindings nativeType = return $ SomeConcreteThing $ NativeType {
		properties = map (Ops.resolve bindings) . nativeType.properties }

instance Thing NativeBitsType where
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing NativeBitsType

instance ParameterizedThing NativeBitsType where
	satisfies (test, candidate) requirement = case asNativeBitsType candidate of
		Just candidateType ->
			testBits test candidateType.size requirement.size candidate (SomeThing requirement)
		Nothing -> case asNativeBitsValue candidate of
			Just candidateValue ->
				testBits test candidateValue.size requirement.size candidate (SomeThing requirement)
			Nothing -> Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve _ nativeBitsType = return $ SomeConcreteThing nativeBitsType

instance Thing NativeCharType where
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing NativeCharType

instance ParameterizedThing NativeCharType where
	satisfies (test, candidate) requirement = case candidate of
		SomeThing thing -> case cast thing :: Maybe NativeCharType of
			Just _ -> Falue test
			Nothing -> case asNativeCharValue candidate of
				Just _ -> Falue test
				Nothing -> Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve _ nativeCharType = return $ SomeConcreteThing nativeCharType

instance Thing NativeStringType where
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing NativeStringType

instance ParameterizedThing NativeStringType where
	satisfies (test, candidate) requirement = case candidate of
		SomeThing thing -> case cast thing :: Maybe NativeStringType of
			Just _ -> Falue test
			Nothing -> case asNativeStringValue candidate of
				Just _ -> Falue test
				Nothing -> Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve _ nativeStringType = return $ SomeConcreteThing nativeStringType

instance Thing thing => Thing (NativeListType thing) where
	toCode = pack . show
	normalize NativeListType{elementType} =
		SomeThing $ NativeListType $ Thing.normalize elementType
	parameterize NativeListType{elementType} =
		SomeParameterizedThing $ NativeListType $ Thing.parameterize elementType

instance ConcreteThing (NativeListType SomeConcreteThing)

instance ParameterizedThing (NativeListType SomeParameterizedThing) where
	satisfies (test, candidate) requirement = case asNativeListTypeP candidate of
		Just candidateType ->
			(test, Thing.parameterize candidateType.elementType)
				`Test.satisfiesDuring` requirement.elementType
		Nothing -> case asNativeSomeTypeP candidate of
			Just candidateType ->
				(test, Thing.parameterize candidateType.elementType)
					`Test.satisfiesDuring` requirement.elementType
			Nothing -> case asNativeListValue candidate of
				Just candidateValue ->
					testListLikeType test requirement.elementType candidateValue.values
				Nothing -> case asNativeSomeValue candidate of
					Just candidateValue ->
						testListLikeType test requirement.elementType candidateValue.valuesP.l
					Nothing -> Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve bindings requirement = do
		resolvedElementType <- Thing.resolve bindings requirement.elementType
		return $ SomeConcreteThing $ NativeListType {
			elementType = resolvedElementType }

instance Thing thing => Thing (NativeSomeType thing) where
	toCode = pack . show
	normalize NativeSomeType{elementType} =
		SomeThing $ NativeSomeType $ Thing.normalize elementType
	parameterize NativeSomeType{elementType} =
		SomeParameterizedThing $ NativeSomeType $ Thing.parameterize elementType

instance ConcreteThing (NativeSomeType SomeConcreteThing)

instance ParameterizedThing (NativeSomeType SomeParameterizedThing) where
	satisfies (test, candidate) requirement = case asNativeSomeTypeP candidate of
		Just candidateType ->
			(test, Thing.parameterize candidateType.elementType)
				`Test.satisfiesDuring` requirement.elementType
		Nothing -> case asNativeSomeValue candidate of
			Just candidateValue ->
				testListLikeType test requirement.elementType candidateValue.valuesP.l
			Nothing -> Error $ PrimitiveMismatch candidate $ SomeThing requirement
	resolve bindings requirement = do
		resolvedElementType <- Thing.resolve bindings requirement.elementType
		return $ SomeConcreteThing $ NativeSomeType {
			elementType = resolvedElementType }

instance Thing thing => Thing (NativeOptionalType thing) where
	toCode = pack . show
	normalize NativeOptionalType{falueType} =
		SomeThing $ NativeOptionalType $ Thing.normalize falueType
	parameterize NativeOptionalType{falueType} =
		SomeParameterizedThing $ NativeOptionalType $ Thing.parameterize falueType

instance ConcreteThing (NativeOptionalType SomeConcreteThing)

instance ParameterizedThing (NativeOptionalType SomeParameterizedThing) where
	satisfies (test, candidate) requirement = case asNativeOptionalTypeP candidate of
		Just candidateType ->
			(test, Thing.parameterize candidateType.falueType)
				`Test.satisfiesDuring` requirement.falueType
		Nothing -> case asNativeOptionalValue candidate of
			Just candidateValue -> case candidateValue.fal of
				Error _ -> Falue test
				Falue value ->
					(test, Thing.parameterize value) `Test.satisfiesDuring` requirement.falueType
			Nothing -> (test, Thing.parameterize candidate)
				`Test.satisfiesDuring` requirement.falueType
	resolve bindings requirement = do
		resolvedFalueType <- Thing.resolve bindings requirement.falueType
		return $ SomeConcreteThing $ NativeOptionalType {
			falueType = resolvedFalueType }

instance Thing thing => Thing (NativeOrType thing) where
	toCode = pack . show
	normalize NativeOrType{options} =
		SomeThing $ NativeOrType $ P2.map Thing.normalize options
	parameterize NativeOrType{options} =
		SomeParameterizedThing $ NativeOrType $ P2.map Thing.parameterize options
	satisfiesAsCandidate test NativeOrType{options} requirement = Just do
		let satisfyOption testResult candidate = case testResult of
			Error e -> Error e
			Falue optionTest -> case (optionTest, candidate) `Test.satisfiesDuring` requirement of
				Error e -> Error e
				Falue nextTest -> Falue test {
					candidateParameterMatches = nextTest.candidateParameterMatches,
					requirementParameterMatches = nextTest.requirementParameterMatches }
		foldl satisfyOption (Falue test) $
			P2.map (Thing.parameterize . Thing.normalize) options

instance ConcreteThing (NativeOrType SomeConcreteThing)

instance ParameterizedThing (NativeOrType SomeParameterizedThing) where
	satisfies (test, candidate) requirement =
		satisfyAny test candidate requirement.options.l
	resolve bindings requirement = do
		resolvedOptions <- traverse (Thing.resolve bindings) requirement.options
		return $ SomeConcreteThing $ NativeOrType { options = resolvedOptions }

instance Thing One where
	toCode = pack . show
	parameterize = SomeParameterizedThing

instance ConcreteThing One

instance ParameterizedThing One where
	resolve _ one = return $ SomeConcreteThing one

instance Thing (CombinedThings SomeThing) where
	propsWith CombinedThings{things} one = concatMap (`propsWithSome` one) things.l
	toCode = pack . show
	normalize CombinedThings{things} =
		SomeThing $ CombinedThings $ fmap Thing.normalize things
	parameterize CombinedThings{things} =
		SomeParameterizedThing $ CombinedThings $ fmap Thing.parameterize things

instance Thing (CombinedThings SomeParameterizedThing) where
	propsWith CombinedThings{things} one =
		concatMap (\thing -> propsWithSome (SomeThing thing) one) things.l
	toCode = pack . show
	normalize CombinedThings{things} =
		SomeThing $ CombinedThings $ fmap Thing.normalize things
	parameterize = SomeParameterizedThing

instance Thing (CombinedThings SomeConcreteThing) where
	propsWith CombinedThings{things} one =
		concatMap (\thing -> propsWithSome (SomeThing thing) one) things.l
	toCode = pack . show
	normalize CombinedThings{things} =
		SomeThing $ CombinedThings $ fmap Thing.normalize things
	parameterize CombinedThings{things} =
		SomeParameterizedThing $ CombinedThings $ fmap Thing.parameterize things

instance ConcreteThing (CombinedThings SomeConcreteThing)

instance ParameterizedThing (CombinedThings SomeParameterizedThing) where
	satisfies (test, candidate) requirement =
		satisfyAll test candidate requirement.things.l
	resolve bindings requirement = do
		resolvedThings <- traverse (Thing.resolve bindings) requirement.things
		return $ SomeConcreteThing $ CombinedThings { things = resolvedThings }

instance Thing (NamedThing SomeThing) where
	propsWith NamedThing{value} = propsWithSome $ SomeThing value
	toCode = pack . show
	normalize NamedThing{value} = Thing.normalize value
	parameterize NamedThing{name, value} =
		SomeParameterizedThing $ NamedThing name $ Thing.parameterize value

instance Thing (NamedThing SomeParameterizedThing) where
	propsWith NamedThing{value} = propsWithSome $ SomeThing value
	toCode = pack . show
	normalize NamedThing{value} = Thing.normalize value
	parameterize = SomeParameterizedThing

instance Thing (NamedThing SomeConcreteThing) where
	propsWith NamedThing{value} = propsWithSome $ SomeThing value
	toCode = pack . show
	normalize NamedThing{value} = Thing.normalize value
	parameterize NamedThing{name, value} =
		SomeParameterizedThing $ NamedThing name $ Thing.parameterize value

instance ConcreteThing (NamedThing SomeConcreteThing)

instance ParameterizedThing (NamedThing SomeParameterizedThing) where
	satisfies (test, _) requirement =
		continueCurrentWith test requirement.value
	resolve bindings requirement = do
		resolvedValue <- Thing.resolve bindings requirement.value
		return $ SomeConcreteThing $ NamedThing {
			name = requirement.name,
			value = resolvedValue }

undefined :: Declaration -> FallibleI Undefined SomeThing
undefined declaration = Error $ Undefined [("", declaration)]

propsOf :: SomeThing -> [SomeOperator]
propsOf one = propsWithSome one one

defsOf :: SomeThing -> [Definition]
defsOf = filterDefs . propsOf

satisfiesThing :: (Context, SomeThing) -> SomeParameterizedThing -> TypeTestResult
satisfiesThing (context, candidate) requirement = do
	let test = Test.fromContext context (Thing.parameterize candidate) requirement
	Test.runTest test
