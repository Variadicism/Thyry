module Beng.Things (
	thing,
	toCode,
	undefined,
	propsOf,
	defsOf,
	satisfies,
	module Beng.Types.Things
) where

import Prelude hiding (undefined)

import Utils.Fallible hiding (fromMaybe)
import Utils.Lists (equalsIgnoreOrder, showWithAnd, showWithOr, wrap)
import Utils.Messaging (Messagable, msg, msgList)
import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 ()
import Utils.Strings (aOrAn, parenthesize)
import Utils.Tuples (mapFst2, toList2)

import Beng.Operators (filterDefs)
import Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import Beng.Invocations ()
import qualified Beng.Invocations as Inv
import qualified Beng.Build.TypeTest as ST
import Beng.Types.Operators (SomeOperator(..))
import Beng.Types.Build.Context (Context)
import Beng.Types.Operators.Declarations (Declaration)
import Beng.Types.Operators.Definitions (Definition)
import Beng.Types.Build.TypeTest (TypeTestResult)
import Beng.Types.Things (Mismatch(..), Undefined(..), Thing(..), Thing(..))
import qualified Beng.Types.Things as Mismatch

import qualified Data.ByteString as BS
import Data.List (intercalate)
import Data.List.Extra (takeEnd)
import Data.Map (Map, assocs)
import Data.Text.Lazy (Text, pack)
import qualified Data.Text.Lazy as Text
import Numeric (showHex)

-- constants

thing :: Thing
thing = NativeType $ const []

-- private

showArg :: String -> String -> String
showArg name typeString = "'" ++ name ++ ", " ++ aOrAn typeString ++ "'"

showArgsUsing :: (Thing -> String) -> Map String Thing -> String
showArgsUsing showT = showWithAnd . map (\(key, argType) -> showArg key $ showT argType) . assocs

showMismatchUsing :: Bool -> Mismatch -> String
showMismatchUsing useMsg = \case
	MismatchedArgument{..} -> "'" ++ name ++ "' was expected to be " ++ show' sub ++
		", but it was " ++ show' super ++ "!"
	MissingArgument{..} -> showArg name (show' sub) ++ " was not found in " ++ showArgsUsing show' superArgs
	ExtraArgument{..} -> showArg name (show' super) ++ " was not expected; only " ++
		showArgsUsing show' subArgs ++ " were!"
	UnsatisfiedProperty{..} -> "it did not satisfy " ++ show' property ++ ": " ++ show' decMismatch
	ObscuredProperty{..} -> "it obscured " ++ show' property ++ ": " ++ show' decMismatch
	UnsatisfiedParent{..} ->
		show' super ++ " does not satisfy its parent, " ++ show' parent ++ ": " ++ show' cause
	PrimitiveMismatch{..} -> show' super ++ " does not satisfy " ++ show' sub ++ "!"
	Tautology{..} -> show' super ++ " can only satisfy " ++ show' sub ++ " tautologically!"
	CompoundMismatch{..} -> showCompoundErrorsUsing show' context compound
	where
		show' :: (Show a, Messagable a) => (a -> String)
		show' = if useMsg then msg else show

-- instances

deriving instance Eq Mismatch

instance Show Mismatch where
	show = showMismatchUsing False

instance Messagable Mismatch where
	msg = showMismatchUsing True

instance Ord Mismatch where
	compare CompoundMismatch{..} m = compare compound.head m
	compare m CompoundMismatch{..} = compare m compound.head
	compare m1 m2 = compare (typeIndex m1) (typeIndex m2)
		where typeIndex = \case
			 MismatchedArgument{} -> 1
			 MissingArgument{} -> 2
			 ExtraArgument{} -> 3
			 UnsatisfiedProperty{} -> 4
			 ObscuredProperty{} -> 5
			 UnsatisfiedParent{} -> 6
			 PrimitiveMismatch{} -> 7
			 Tautology{} -> 8
			 CompoundMismatch{} -> 9 -- impossible

instance IsError Mismatch where
	prepend newContext = \case
		cm@CompoundMismatch{} -> cm{ Mismatch.context = newContext ++ cm.context }
		mismatch -> CompoundMismatch { context = newContext, compound = P.singleton mismatch }
	(<!>) m1 m2 = do
		let getCompound = \case
			CompoundMismatch{..} -> Just (context, compound)
			_ -> Nothing
		compoundErrorsUsing getCompound CompoundMismatch m1 m2

deriving instance Eq Undefined

instance Show Undefined where
	show Undefined{decsByContext} = intercalate "\n" $
		map (\(context, declaration) -> context ++ show declaration ++ " :/=") decsByContext

instance Messagable Undefined where
	msg = show

instance IsError Undefined where
	prepend context Undefined{decsByContext} = Undefined $ map (mapFst2 (context++)) decsByContext
	(<!>) u1 u2 = Undefined $ u1.decsByContext ++ u2.decsByContext

instance Eq Thing where
	(==) t1@NativeType{} t2@NativeType{} = t1.properties One `equalsIgnoreOrder` t2.properties One
	-- /\ This needed custom implementation since properties is a function and can't `==`.
	-- \/ These COULD HAVE BEEN derived, but I can't "partailly derive", so... :|
	(==) (InvValue o1) (InvValue o2) = o1 == o2
	(==) (DefinitionValue d1) (DefinitionValue d2) = d1 == d2
	(==) (DeclarationValue d1) (DeclarationValue d2) = d1 == d2
	(==) (PatternValue p1) (PatternValue p2) = p1 == p2
	(==) op1@OpType{} op2@OpType{} = op1.returnType == op2.returnType && op1.args == op2.args
	(==) DefinitionType DefinitionType = True
	(==) DeclarationType DeclarationType = True
	(==) PatternType PatternType = True
	(==) (PreOpType r1) (PreOpType r2) = r1 == r2
	(==) (NativeBitsValue bs1 s1) (NativeBitsValue bs2 s2) = s1 == s2 && bs1 == bs2
	(==) (NativeCharValue c1) (NativeCharValue c2) = c1 == c2
	(==) (NativeStringValue s1) (NativeStringValue s2) = s1 == s2
	(==) (NativeListValue l1) (NativeListValue l2) = l1 == l2
	(==) (NativeSomeValue s1) (NativeSomeValue s2) = s1 == s2
	(==) (NativeOptionalValue o1) (NativeOptionalValue o2) = o1 == o2
	(==) (NativeBitsType b1) (NativeBitsType b2) = b1 == b2
	(==) NativeCharType NativeCharType = True
	(==) NativeStringType NativeStringType = True
	(==) (NativeListType e1) (NativeListType e2) = e1 == e2
	(==) (NativeSomeType e1) (NativeSomeType e2) = e1 == e2
	(==) (NativeOptionalType f1) (NativeOptionalType f2) = f1 == f2
	(==) (NativeOrType o1) (NativeOrType o2) = o1 == o2
	(==) One One = True
	(==) (CombinedThings vs1) (CombinedThings vs2) = vs1 == vs2
	(==) (NamedThing _ v1) (NamedThing _ v2) = v1 == v2
	(==) (NamedThing _ v1) v2 = v1 == v2
	(==) v1 (NamedThing _ v2) = v1 == v2
	(==) _ _ = False

instance Show Thing where
	show = \case
		InvValue inv -> show inv
		DefinitionValue def -> show def
		DeclarationValue dec -> show dec
		PatternValue pattern -> show pattern
		OpType{args,returnType} ->
			if null args then
				show returnType ++ " op"
			else do
				let argToString argName argType = argName ++ ", a(n) " ++ show argType
				let argStrings = map (uncurry argToString) $ assocs args
				showWithAnd argStrings ++ " => " ++ show returnType
		DefinitionType -> "op definition"
		DeclarationType -> "op declaration"
		PatternType -> "op pattern"
		PreOpType{resolvedType} -> "a preop of " ++ show resolvedType
		NativeBitsType{size=1} -> "a bit"
		NativeBitsType{size} -> show size ++ " bits"
		NativeCharValue{char} -> wrap "'" [char]
		NativeStringValue{text} -> show text
		NativeListValue{values} -> show values
		NativeSomeValue{valuesP} -> show valuesP
		NativeOptionalValue{fal} -> show fal
		NativeType{..} -> if null $ properties One
			then "thing"
			else showWithAnd $ properties One
		NativeBitsValue{bytes} ->
			"0x" ++ concatMap (\b -> takeEnd 2 $ '0':showHex b "") (BS.unpack bytes)
		NativeCharType -> "a native char"
		NativeStringType -> "a native string"
		NativeListType{elementType} -> "a native list of " ++ show elementType  -- TODO: pluralize elementType
		NativeSomeType{elementType} -> "a native some " ++ show elementType  -- TODO: pluralize
		-- TODO: remove a(n) from the falueType
		NativeOptionalType{falueType} -> "a native " ++ show falueType ++ "?"
		NativeOrType{options} -> "a native " ++ showWithOr options.l
		One -> "one"
		CombinedThings{..} -> intercalate " + " $ map show things.l
		NamedThing{..} -> parenthesize $ name ++ " := " ++ show value

instance Messagable Thing where
	msg = \case
		InvValue inv -> msg inv
		DefinitionValue def -> msg def
		DeclarationValue dec -> msg dec
		PatternValue pat -> msg pat
		PreOpType{resolvedType} -> "a preop of " ++ msg resolvedType
		NativeCharValue{char} -> wrap "'" [char]
		NativeStringValue{text} -> msg text
		NativeListValue{values} -> msgList values
		NativeSomeValue{valuesP} -> msg valuesP
		NativeOptionalValue{fal} -> fallible ((++"!") . show) show fal
		NativeType{..} -> if null $ properties One
			then "thing"
			else msgList $ properties One
		NativeCharType -> "a char"
		NativeStringType -> "a string"
		NativeListType{elementType} -> "a list of " ++ show elementType  -- TODO: pluralize elementType
		NativeSomeType{elementType} -> "some " ++ show elementType  -- TODO: pluralize
		NativeOptionalType{falueType} -> show falueType ++ "?"
		NativeOrType{options} -> showWithOr options.l
		CombinedThings{..} -> intercalate " + " $ map msg things.l
		NamedThing{..} -> name
		v -> show v

-- exported

toCode :: Thing -> Text
toCode = \case
	-- TODO: replace most "pack $ show"s with their own toCodes (and probably a class).
	InvValue invocation -> Inv.toCode invocation
	DefinitionValue def -> pack $ show def
	DeclarationValue dec -> pack $ show dec
	PatternValue pat -> pack $ show pat
	NativeBitsValue{bytes} -> pack $ show bytes  -- TODO: probably replace with hex digits
	NativeCharValue{char} -> pack ['\'', char, '\'']
	NativeStringValue{text} -> Text.concat ["\"", text, "\""]  -- TODO: encode as Beng string
	NativeListValue{values} -> case values of
		[] -> "[]"
		[solo] -> toCode solo
		[first, second] -> Text.concat [toCode first, " and ", toCode second]
		many -> Text.concat $
			(concatMap toList2 $ zip (map toCode $ init many) (repeat ", ")) ++
			["and ", toCode $ last many]
	NativeSomeValue{valuesP} -> toCode $ NativeListValue valuesP.l
	NativeOptionalValue{fal} -> case fal of
		Falue falue -> toCode falue
		Error error -> Text.concat ["\"", pack $ msg error, "\"!"]
	thing -> pack $ show thing

undefined :: Declaration -> FallibleI Undefined Thing
undefined declaration = Error $ Undefined [("", declaration)]

propsWithOf :: Thing -> Thing -> [SomeOperator]
propsWithOf one = \case
	CombinedThings{..} -> concatMap (propsWithOf one) things -- TODO: filter out polysemy
	DefinitionValue def -> [SomeOperator def]
	DeclarationValue dec -> [SomeOperator dec]
	nt@NamedThing{..} -> propsWithOf one nt.value -- TODO: add type names as ops
	NativeType{..} -> properties one
	_ -> []

propsOf :: Thing -> [SomeOperator]
propsOf one = propsWithOf one one

defsOf :: Thing -> [Definition]
defsOf = filterDefs . propsOf

{- This is NOT meant to be used recursively!
   Try the TypeTest instead as it can avoid infinite recursions from tautologies.
   For example, imagine the context at the bottom was asked if `dog` satisfies `animal`.
   The PatternComparator would match "yell as " in animal's yell dec on line 1 and the def on line 3.
   But, when it gets to the argument, it tries to match Dog to One by seeing if a dog is an animal.
   This is identical to the initial question, so it recurses... infinitely.
   TypeTest instead keeps `dog satisfies? animal` under the "ongoing" field;
   that way, it can detect the recursion and handle it appropriately.
   ```
   \animal := yell as 'One' => string
   \dog := fetch 'Thing' as 'One' := Thing
   \yell as 'Dog' := "bark"
   ``` -}
satisfies :: (Context, Thing) -> Thing -> TypeTestResult
satisfies (context, super) sub =
	ST.runTest $ ST.fromContext context super sub
