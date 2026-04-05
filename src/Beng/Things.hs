module Beng.Things (
    thing,
    toCode,
    undefined,
    propsOf,
    defsOf,
    satisfiesThing,
    module Beng.Types.Things
) where

import Prelude hiding (undefined)

import Utils.Fallible hiding (fromMaybe)
import Utils.Lists (equalsIgnoreOrder, showWithAnd, showWithOr, wrap)
import Utils.Messaging (Messagable, msg, msgList)
import qualified Utils.Populace as P
import Utils.Strings (aOrAn, parenthesize)
import Utils.Tuples (mapFst2, toList2)

import qualified Beng.Build.TypeTest as Test
import Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import Beng.Invocations ()
import qualified Beng.Invocations as Inv
import Beng.Operators (filterDefs)
import qualified Beng.Types.Operators as Ops
import Beng.Types.Build.Context (Context)
import Beng.Types.Build.TypeTest (TypeTest, TypeTestResult)
import qualified Beng.Types.Build.TypeTest as TypeTest
import qualified Beng.Types.Things as TThing
import Beng.Types.Invocations (SomeInvocation)
import Beng.Types.Operators (SomeOperator(..))
import Beng.Types.Operators.Declarations (Declaration)
import Beng.Types.Operators.Definitions (Definition)
import Beng.Types.Parse.Patterns (SomePattern)
import Beng.Types.Things (
    Mismatch(..),
    Undefined(..),
    Thing(satisfies, propsWith),
    SomeThing(..),
    OpType(..),
    DefinitionType(..),
    DeclarationType(..),
    PatternType(..),
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
    NamedThing(..),
    castThing )
import qualified Beng.Types.Things as Mismatch

import Control.Monad (void)
import qualified Data.ByteString as BS
import Data.List (intercalate)
import Data.List.Extra (takeEnd)
import Data.Map (Map, assocs)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text.Lazy (Text, pack)
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
            "'" ++ name ++ "' was expected to be " ++ showThing sub ++
                ", but it was " ++ showThing super ++ "!"
        MissingArgument{..} ->
            showArg name (showThing sub) ++ " was not found in " ++ showArgsUsing showThing superArgs
        ExtraArgument{..} ->
            showArg name (showThing super) ++ " was not expected; only " ++
                showArgsUsing showThing subArgs ++ " were!"
        UnsatisfiedProperty{..} ->
            "it did not satisfy " ++ show property ++ ": " ++ show decMismatch
        ObscuredProperty{..} ->
            "it obscured " ++ show property ++ ": " ++ show decMismatch
        UnsatisfiedParent{..} ->
            showThing super ++ " does not satisfy its parent, " ++ showThing parent ++ ": " ++
                showMismatch cause
        PrimitiveMismatch{..} ->
            showThing super ++ " does not satisfy " ++ showThing sub ++ "!"
        Tautology{..} ->
            showThing super ++ " can only satisfy " ++ showThing sub ++ " tautologically!"
        CompoundMismatch{..} ->
            showCompoundErrorsUsing showMismatch context compound

stripNames :: SomeThing -> SomeThing
stripNames thing0 = case thing0 of
    SomeThing thing -> case asNamedThing (SomeThing thing) of
        Just namedThing -> stripNames namedThing.value
        Nothing -> SomeThing thing

propsWithSome :: SomeThing -> SomeThing -> [SomeOperator]
propsWithSome (SomeThing value) one = value `propsWith` one

asNamedThing :: (SomeThing -> Maybe (NamedThing SomeThing))
asNamedThing = castThing

asCombinedThings :: (SomeThing -> Maybe CombinedThings)
asCombinedThings = castThing

asNativeType :: (SomeThing -> Maybe NativeType)
asNativeType = castThing

asNativeOrType :: (SomeThing -> Maybe NativeOrType)
asNativeOrType = castThing

asOpType :: (SomeThing -> Maybe OpType)
asOpType = castThing

asNativeListValue :: (SomeThing -> Maybe NativeListValue)
asNativeListValue = castThing

asNativeSomeValue :: (SomeThing -> Maybe NativeSomeValue)
asNativeSomeValue = castThing

asNativeBitsType :: (SomeThing -> Maybe NativeBitsType)
asNativeBitsType = castThing

asNativeBitsValue :: (SomeThing -> Maybe NativeBitsValue)
asNativeBitsValue = castThing

asNativeCharValue :: (SomeThing -> Maybe NativeCharValue)
asNativeCharValue = castThing

asNativeStringValue :: (SomeThing -> Maybe NativeStringValue)
asNativeStringValue = castThing

asNativeListType :: (SomeThing -> Maybe (NativeListType SomeThing))
asNativeListType = castThing

asNativeSomeType :: (SomeThing -> Maybe (NativeSomeType SomeThing))
asNativeSomeType = castThing

asNativeOptionalType :: (SomeThing -> Maybe (NativeOptionalType SomeThing))
asNativeOptionalType = castThing

asNativeOptionalValue :: (SomeThing -> Maybe (NativeOptionalValue SomeThing))
asNativeOptionalValue = castThing

satisfiesProps :: (TypeTest, SomeThing) -> (SomeThing -> [SomeOperator]) -> FallibleI Mismatch ()
satisfiesProps (test, candidate) propsWith = do
    let checkProp (SomeOperator op) = Ops.hasProp test op
    void $ sequence $ map checkProp $ propsWith candidate

testBits :: Int -> Int -> SomeThing -> SomeThing -> FallibleI Mismatch ()
testBits superSize subSize super sub =
    if superSize <= subSize then
        Falue ()
    else
        Error $ PrimitiveMismatch super sub

testListLike ::
    TypeTest -> SomeThing -> SomeThing -> [SomeThing] -> [SomeThing] -> FallibleI Mismatch ()
testListLike test super sub supers subs =
    if length supers < length subs then
        Error $ PrimitiveMismatch super sub
    else do
        void $ sequence $ zipWith
            (\superElement subElement -> (test, superElement) `Test.satisfiesDuring` subElement)
            supers
            subs

testListLikeType :: TypeTest -> SomeThing -> [SomeThing] -> FallibleI Mismatch ()
testListLikeType test elementType values =
    void $ sequence $ map (\value -> (test, value) `Test.satisfiesDuring` elementType) values

primitiveMismatch :: SomeThing -> SomeThing -> FallibleI Mismatch ()
primitiveMismatch super sub = Error $ PrimitiveMismatch super sub

normalizeThing :: Thing thing => thing -> SomeThing
normalizeThing thing = case cast thing of
    Just someThing -> someThing
    Nothing -> SomeThing thing

primitiveSatisfies :: (Thing super, Thing sub) => TypeTest -> super -> sub -> FallibleI Mismatch ()
primitiveSatisfies test super sub = do
    let someSuper = normalizeThing super
    let someSub = normalizeThing sub
    case asNamedThing someSub of
        Just namedThing -> Test.runTest test {
            TypeTest.current = test.current {
                TypeTest.requirement = namedThing.value,
                TypeTest.requirementName = Just namedThing.name } }
        Nothing -> case asCombinedThings someSub of
            Just combinedThings ->
                void $ sequence $ map ((test, someSuper) `Test.satisfiesDuring`) combinedThings.things.l
            Nothing -> case asNativeType someSub of
                Just nativeType ->
                    (test, someSuper) `satisfiesProps` nativeType.properties
                Nothing -> case asNativeOrType someSub of
                    Just nativeOrType ->
                        void $ sequence $
                            map (\subOption -> (test, subOption) `Test.satisfiesDuring` someSuper) $
                                nativeOrType.options.l
                    Nothing -> primitiveMismatch someSuper someSub

argKeysOf :: Map String SomeThing -> Map String SomeThing -> Set String
argKeysOf superArgs subArgs =
    Set.union (Set.fromList $ Map.keys superArgs) (Set.fromList $ Map.keys subArgs)

instance Eq SomeThing where
    left == right = case (stripNames left, stripNames right) of
        (SomeThing (leftThing :: leftThing), rightThing) -> case castThing rightThing of
            Just rightThing' -> leftThing == (rightThing' :: leftThing)
            Nothing -> False

instance Show SomeThing where
    show (SomeThing value) = show value

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
deriving instance Eq NativeListValue
deriving instance Eq NativeSomeValue
deriving instance Eq thing => Eq (NativeOptionalValue thing)
deriving instance Eq NativeBitsType
deriving instance Eq NativeCharType
deriving instance Eq NativeStringType
deriving instance Eq thing => Eq (NativeListType thing)
deriving instance Eq thing => Eq (NativeSomeType thing)
deriving instance Eq thing => Eq (NativeOptionalType thing)
deriving instance Eq NativeOrType
deriving instance Eq One
deriving instance Eq CombinedThings
deriving instance Eq thing => Eq (NamedThing thing)

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

instance Show thing => Show (PreOpType thing) where
    show PreOpType{resolvedType} = "a preop of " ++ show resolvedType

instance Show NativeBitsValue where
    show NativeBitsValue{bytes} =
        "0x" ++ concatMap (\byte -> takeEnd 2 $ '0' : showHex byte "") (BS.unpack bytes)

instance Show NativeCharValue where
    show NativeCharValue{char} = wrap "'" [char]

instance Show NativeStringValue where
    show NativeStringValue{text} = show text

instance Show NativeListValue where
    show NativeListValue{values} = show values

instance Show NativeSomeValue where
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

instance Show thing => Show (NativeListType thing) where
    show NativeListType{elementType} = "a native list of " ++ show elementType

instance Show thing => Show (NativeSomeType thing) where
    show NativeSomeType{elementType} = "a native some " ++ show elementType

instance Show thing => Show (NativeOptionalType thing) where
    show NativeOptionalType{falueType} = "a native " ++ show falueType ++ "?"

instance Show NativeOrType where
    show NativeOrType{options} = "a native " ++ showWithOr options.l

instance Show One where
    show One = "one"

instance Show CombinedThings where
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

instance Messagable thing => Messagable (PreOpType thing) where
    msg PreOpType{resolvedType} = "a preop of " ++ msg resolvedType

instance Messagable NativeBitsValue where
    msg = show

instance Messagable NativeCharValue where
    msg NativeCharValue{char} = wrap "'" [char]

instance Messagable NativeStringValue where
    msg NativeStringValue{text} = msg text

instance Messagable NativeListValue where
    msg NativeListValue{values} = msgList values

instance Messagable NativeSomeValue where
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

instance Show thing => Messagable (NativeListType thing) where
    msg NativeListType{elementType} = "a list of " ++ show elementType

instance Show thing => Messagable (NativeSomeType thing) where
    msg NativeSomeType{elementType} = "some " ++ show elementType

instance Show thing => Messagable (NativeOptionalType thing) where
    msg NativeOptionalType{falueType} = show falueType ++ "?"

instance Messagable NativeOrType where
    msg NativeOrType{options} = showWithOr options.l

instance Messagable One where
    msg = show

instance Messagable CombinedThings where
    msg CombinedThings{things} = intercalate " + " $ map msg things.l

instance Messagable thing => Messagable (NamedThing thing) where
    msg NamedThing{name} = name

instance Thing SomeThing where
    satisfies (test, SomeThing thing) = satisfies (test, thing)
    propsWith (SomeThing thing) = propsWith thing
    toCode (SomeThing thing) = TThing.toCode thing

instance Thing SomeInvocation where
    satisfies (test, invocation) = primitiveSatisfies test $ SomeThing invocation
    toCode = Inv.toCode

instance Thing Definition where
    satisfies (test, definition) = primitiveSatisfies test $ SomeThing definition
    propsWith definition _ = [SomeOperator definition]
    toCode = pack . show

instance Thing Declaration where
    satisfies (test, declaration) = primitiveSatisfies test $ SomeThing declaration
    propsWith declaration _ = [SomeOperator declaration]
    toCode = pack . show

instance Thing SomePattern where
    satisfies (test, somePattern) = primitiveSatisfies test $ SomeThing somePattern
    toCode = pack . show

instance Thing OpType where
    satisfies (test, super) subThing = case asOpType subThing of
        Just sub -> do
            (test, super.returnType) `Test.satisfiesDuring` sub.returnType
            void $ sequence $ map
                (\key -> case (super.args Map.!? key, sub.args Map.!? key) of
                    (Nothing, Nothing) -> primitiveMismatch (SomeThing super) (SomeThing sub)
                    (Just superArgType, Nothing) -> Error $ ExtraArgument key superArgType sub.args
                    (Nothing, Just subArgType) -> Error $ MissingArgument key subArgType super.args
                    (Just superArgType, Just subArgType) ->
                        mapError (MismatchedArgument key superArgType subArgType) $
                            (test, subArgType) `Test.satisfiesDuring` superArgType)
                $ Set.elems $ argKeysOf super.args sub.args
        Nothing -> primitiveSatisfies test (SomeThing super) subThing
    propsWith _ _ = []
    toCode = pack . show

instance Thing DefinitionType where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode = pack . show

instance Thing DeclarationType where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode = pack . show

instance Thing PatternType where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode = pack . show

instance Thing thing => Thing (PreOpType thing) where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode = pack . show

instance Thing NativeBitsValue where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode NativeBitsValue{bytes} = pack $ show bytes

instance Thing NativeCharValue where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode NativeCharValue{char} = pack ['\'', char, '\'']

instance Thing NativeStringValue where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode NativeStringValue{text} = Text.concat ["\"", text, "\""]

instance Thing NativeListValue where
    satisfies (test, super) subThing = case asNativeListValue subThing of
        Just sub ->
            testListLike test (SomeThing super) (SomeThing sub) super.values sub.values
        Nothing -> case asNativeSomeValue subThing of
            Just sub ->
                testListLike test (SomeThing super) (SomeThing sub) super.values sub.valuesP.l
            Nothing -> primitiveSatisfies test (SomeThing super) subThing
    toCode NativeListValue{values} = case values of
        [] -> "[]"
        [solo] -> toCode solo
        [first, second] -> Text.concat [toCode first, " and ", toCode second]
        many -> Text.concat $
            (concatMap toList2 $ zip (map toCode $ init many) (repeat ", ")) ++
            ["and ", toCode $ last many]

instance Thing NativeSomeValue where
    satisfies (test, super) subThing = case asNativeSomeValue subThing of
        Just sub ->
            testListLike test (SomeThing super) (SomeThing sub) super.valuesP.l sub.valuesP.l
        Nothing -> case asNativeListValue subThing of
            Just sub ->
                testListLike test (SomeThing super) (SomeThing sub) super.valuesP.l sub.values
            Nothing -> primitiveSatisfies test (SomeThing super) subThing
    toCode NativeSomeValue{valuesP} = toCode $ SomeThing $ NativeListValue valuesP.l

instance Thing thing => Thing (NativeOptionalValue thing) where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode NativeOptionalValue{fal} = case fal of
        Falue falue -> TThing.toCode falue
        Error error -> Text.concat ["\"", pack $ msg error, "\"!"]

instance Thing NativeType where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    propsWith = properties
    toCode = pack . show

instance Thing NativeBitsType where
    satisfies (_, super) subThing = case asNativeBitsType subThing of
        Just sub ->
            testBits super.size sub.size (SomeThing super) (SomeThing sub)
        Nothing -> case asNativeBitsValue subThing of
            Just sub ->
                testBits super.size sub.size (SomeThing super) (SomeThing sub)
            Nothing -> Error $ PrimitiveMismatch (SomeThing super) subThing
    toCode = pack . show

instance Thing NativeCharType where
    satisfies (test, super) subThing = case asNativeCharValue subThing of
        Just _ -> Falue ()
        Nothing -> primitiveSatisfies test (SomeThing super) subThing
    toCode = pack . show

instance Thing NativeStringType where
    satisfies (test, super) subThing = case asNativeStringValue subThing of
        Just _ -> Falue ()
        Nothing -> primitiveSatisfies test (SomeThing super) subThing
    toCode = pack . show

instance Thing thing => Thing (NativeListType thing) where
    satisfies (test, super) subThing = case asNativeListType subThing of
        Just sub ->
            (test, SomeThing super.elementType) `Test.satisfiesDuring` sub.elementType
        Nothing -> case asNativeSomeType subThing of
            Just sub ->
                (test, SomeThing super.elementType) `Test.satisfiesDuring` sub.elementType
            Nothing -> case asNativeListValue subThing of
                Just sub ->
                    testListLikeType test (SomeThing super.elementType) sub.values
                Nothing -> case asNativeSomeValue subThing of
                    Just sub ->
                        testListLikeType test (SomeThing super.elementType) sub.valuesP.l
                    Nothing -> primitiveSatisfies test (SomeThing super) subThing
    toCode = pack . show

instance Thing thing => Thing (NativeSomeType thing) where
    satisfies (test, super) subThing = case asNativeSomeType subThing of
        Just sub ->
            (test, SomeThing super.elementType) `Test.satisfiesDuring` sub.elementType
        Nothing -> case asNativeSomeValue subThing of
            Just sub ->
                testListLikeType test (SomeThing super.elementType) sub.valuesP.l
            Nothing -> primitiveSatisfies test (SomeThing super) subThing
    toCode = pack . show

instance Thing thing => Thing (NativeOptionalType thing) where
    satisfies (test, super) subThing = case asNativeOptionalType subThing of
        Just sub ->
            (test, SomeThing super.falueType) `Test.satisfiesDuring` sub.falueType
        Nothing -> case asNativeOptionalValue subThing of
            Just sub -> case sub.fal of
                Error _ -> Falue ()
                Falue value -> (test, value) `Test.satisfiesDuring` SomeThing super.falueType
            Nothing -> (test, SomeThing super.falueType) `Test.satisfiesDuring` subThing
    toCode = pack . show

instance Thing NativeOrType where
    satisfies (test, super) sub =
        void $ sequenceAny $ map ((test, sub) `Test.satisfiesDuring`) super.options.l
    toCode = pack . show

instance Thing One where
    satisfies (test, super) = primitiveSatisfies test $ SomeThing super
    toCode = pack . show

instance Thing CombinedThings where
    satisfies (test, super) sub =
        void $ sequenceAny $ map (\value -> (test, value) `Test.satisfiesDuring` sub) super.things.l
    propsWith CombinedThings{things} one = concatMap (`propsWithSome` one) things.l
    toCode = pack . show

instance Thing thing => Thing (NamedThing thing) where
    satisfies (test, super) _ =
        Test.runTest test {
            TypeTest.current = test.current {
                TypeTest.candidate = SomeThing super.value,
                TypeTest.candidateName = Just super.name } }
    propsWith NamedThing{value} = propsWithSome $ SomeThing value
    toCode = pack . show

toCode :: SomeThing -> Text
toCode (SomeThing value) = TThing.toCode value

undefined :: Declaration -> FallibleI Undefined SomeThing
undefined declaration = Error $ Undefined [("", declaration)]

propsOf :: SomeThing -> [SomeOperator]
propsOf one = propsWithSome one one

defsOf :: SomeThing -> [Definition]
defsOf = filterDefs . propsOf

satisfiesThing :: (Context, SomeThing) -> SomeThing -> TypeTestResult
satisfiesThing (context, super) sub =
    Test.runTest $ Test.fromContext context super sub
