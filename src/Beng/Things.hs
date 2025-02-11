module Beng.Things (
	one,
	thing,
	toCode,
	undefined,
	oneIsA,
	module Beng.Types.Things
) where

import Prelude hiding (undefined)

import Utils.Fallible
import Utils.Lists (ifNotNull, showWithAnd, showWithOr, wrap)
import Utils.Messaging (Messagable, msg, msgList)
import qualified Utils.Populace as P
import Utils.Strings (aOrAn)
import Utils.Tuples (mapFst2, toList2)

import Beng.Build.Cards ()
import qualified Beng.Build.Context as Context
import Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import Beng.Ops ()
import qualified Beng.Ops as Op
import Beng.Types.Build.Cards (Card(..))
import Beng.Types.Build.Context (Context)
import Beng.Types.Ops.Declarations (Declaration)
import Beng.Types.Things (Mismatch(..), Undefined(..), Thing(..), Thing(..))

import Control.Monad (void)
import qualified Data.ByteString as BS
import Data.List (intercalate)
import Data.List.Extra (takeEnd)
import Data.Map ((!?), Map, assocs)
import qualified Data.Map as Map
import Data.Maybe (catMaybes)
import qualified Data.Set as Set
import Data.Text.Lazy (Text, pack)
import qualified Data.Text.Lazy as Text
import Numeric (showHex)

-- constants

one :: Thing
one = NativeType { name = Just "one", parents = [], properties = const [] }

thing :: Thing
thing = NativeType { name = Just "thing", parents = [], properties = const [] }

-- private

showArg :: String -> String -> String
showArg name typeString = "'" ++ name ++ ", " ++ aOrAn typeString ++ "'"

showArgsUsing :: (Thing -> String) -> Map String Thing -> String
showArgsUsing showT = showWithAnd . map (\(key, argType) -> showArg key $ showT argType) . assocs

showMismatchUsing :: Bool -> Mismatch -> String
showMismatchUsing useMsg = \case
	MismatchedArgument{..} -> "'" ++ name ++ "' was expected to be " ++ aOrAn (show' sub) ++
		", but it was " ++ aOrAn (show' super) ++ "!"
	MissingArgument{..} -> showArg name (show' sub) ++ " was not found in " ++ showArgsUsing show' superArgs
	ExtraArgument{..} -> showArg name (show' super) ++ " was not expected; only " ++
		showArgsUsing show' subArgs ++ " were!"
	UnsatisfiedProperty{..} -> "it did not satisfy " ++ show' property ++ ": " ++ show' decMismatch
	UnsatisfiedParent{..} -> show' super ++ " was not " ++ aOrAn (show' parent) ++ ": " ++ show' cause
	PrimitiveMismatch{..} -> aOrAn (show' super) ++ " is not " ++ aOrAn (show' sub) ++ "!"
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
			 UnsatisfiedParent{} -> 5
			 PrimitiveMismatch{} -> 6
			 CompoundMismatch{} -> 7 -- impossible

instance IsError Mismatch where
	prepend newContext = \case
		cm@CompoundMismatch{} -> cm{ context = newContext ++ cm.context }
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
	(==) t1@NativeType{} t2@NativeType{} = t1.parents == t2.parents && t1.properties one == t2.properties one
	-- /\ This one needed custom implementation since properties is a function and can't `==`.
	-- \/ These COULD HAVE BEEN derived, but I can't "partailly derive", so... :|
	(==) (ThingValue t1ds) (ThingValue t2ds) = t1ds == t2ds
	(==) (OpValue o1) (OpValue o2) = o1 == o2
	(==) (DefinitionValue d1) (DefinitionValue d2) = d1 == d2
	(==) (DeclarationValue d1) (DeclarationValue d2) = d1 == d2
	(==) (PatternValue p1) (PatternValue p2) = p1 == p2
	(==) op1@OpType{} op2@OpType{} = op1.returnType == op2.returnType && op1.args == op2.args
	(==) DefinitionType DefinitionType = True
	(==) DeclarationType DeclarationType = True
	(==) PatternType PatternType = True
	(==) PreOpType PreOpType = True
	(==) (NativeBitsType b1) (NativeBitsType b2) = b1 == b2
	(==) NativeCharType NativeCharType = True
	(==) NativeStringType NativeStringType = True
	(==) (NativeListType e1) (NativeListType e2) = e1 == e2
	(==) (NativeSomeType e1) (NativeSomeType e2) = e1 == e2
	(==) (NativeOptionalType f1) (NativeOptionalType f2) = f1 == f2
	(==) (NativeOrType o1) (NativeOrType o2) = o1 == o2
	(==) _ _ = False

instance Show Thing where
	show = \case
		ThingValue{definitions} -> show definitions
		OpValue op -> show op
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
		PreOpType -> "preop"		
		NativeBitsType{size} -> show size ++ " bits"
		NativeCharValue{char} -> wrap "'" [char]
		NativeStringValue{text} -> show text
		NativeListValue{values} -> show values
		NativeSomeValue{valuesP} -> show valuesP
		NativeOptionalValue{fal} -> show fal
		NativeType{..} -> do
			let base = if null parents then "thing" else intercalate " + " (map show parents)
			let props = intercalate "\n" $ map show $ properties one
			base ++ ifNotNull (" where\n"++) props
		NativeBitsValue{bytes} ->
			"0x" ++ concatMap (\b -> takeEnd 2 $ '0':showHex b "") (BS.unpack bytes)
		NativeCharType -> "native char"
		NativeStringType -> "native string"
		NativeListType{elementType} -> "native list of " ++ show elementType  -- TODO: pluralize elementType
		NativeSomeType{elementType} -> "native some " ++ show elementType  -- TODO: pluralize
		NativeOptionalType{falueType} -> "native " ++ show falueType ++ "?"
		NativeOrType{options} -> "native " ++ showWithOr options.l

instance Messagable Thing where
	msg = \case
		ThingValue{definitions} -> msg definitions
		OpValue op -> msg op
		DefinitionValue def -> msg def
		DeclarationValue dec -> msg dec
		PatternValue pat -> msg pat
		NativeCharValue{char} -> wrap "'" [char]
		NativeStringValue{text} -> msg text
		NativeListValue{values} -> msgList values
		NativeSomeValue{valuesP} -> msg valuesP
		NativeOptionalValue{fal} -> fallible ((++"!") . show) show fal
		v -> show v

-- exported

toCode :: Thing -> Text
toCode = \case
	-- TODO: replace most "pack $ show"s with their own toCodes (and probably a class).
	ThingValue{definitions} -> Text.concat ["a thing where ", pack (msg definitions)]
	OpValue op -> Op.toCode op
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

oneIsA :: (Context, Thing) -> Thing -> FallibleI Mismatch ()
oneIsA (context, super) sub = do
	let oneIsAThingWith super context parents propsWith = do
		let getUndefined = \case
			DefCard _ -> Nothing
			DecCard declaration -> Just declaration
		let checkProp subProp =
			mapError (UnsatisfiedProperty subProp) $ void $
				context `Context.has` subProp
		{- Fill sub's properties with super because super only needs to satisfy declarations with its own
		   type, not _all_ of the sub's type, e.g., if number declares 'one' + 'one' as a property,
		   int only needs to define 'int' + 'int' to satisfy number's type, not 'number' + 'number'. -}
		sequence $ map checkProp $ catMaybes $ map getUndefined $ propsWith super
		let checkParent parent = mapError (UnsatisfiedParent parent super) $
			(context, super) `oneIsA` parent
		void $ sequence $ map checkParent parents
	case (super, sub) of
		-- congruent types
		(super, sub) | super == sub -> Falue ()
		(super@NativeType{}, sub@NativeType{}) -> do
			let contextWithSuperProps = foldl (flip Context.pushCard) context $ super.properties super
			oneIsAThingWith super contextWithSuperProps sub.parents super.properties
		(super@NativeBitsType{}, sub@NativeBitsType{}) -> ifElseError (super.size <= sub.size) () $
			PrimitiveMismatch super sub
		(super@OpType{}, sub@OpType{}) -> do
			(context, super.returnType) `oneIsA` sub.returnType
			let argKeys = Set.union (Set.fromList $ Map.keys sub.args) (Set.fromList $ Map.keys super.args)
			let checkArgs key = case (super.args !? key, sub.args !? key) of
				(Nothing, Nothing) ->
					error $ "Impossible: there was no '" ++ key ++ "' arg in either " ++ show super ++
						" or " ++ show sub ++ "!"
				(Just superArgType, Nothing) -> Error $ ExtraArgument key superArgType sub.args
				(Nothing, Just subArgType) -> Error $ MissingArgument key subArgType super.args
				(Just superArgType, Just subArgType) ->
					mapError (MismatchedArgument key superArgType subArgType) $
						(context, subArgType) `oneIsA` superArgType
			void $ sequence $ map checkArgs $ Set.elems argKeys
		(super@NativeListType{}, sub@NativeListType{}) ->
			(context, super.elementType) `oneIsA` sub.elementType
		(super@NativeSomeType{}, sub@NativeSomeType{}) ->
			(context, super.elementType) `oneIsA` sub.elementType
		(super@NativeOptionalType{}, sub@NativeOptionalType{}) ->
			(context, super.falueType) `oneIsA` sub.falueType
		-- NativeOrType's implementation is the same regardless of the super type.
		-- disparate types
		(super, sub@NativeType{}) -> oneIsAThingWith super context sub.parents sub.properties
		(super@NativeType{}, sub) ->
			void $ sequenceAny $ map ((context, sub) `oneIsA`) super.parents
		(super@NativeSomeType{}, sub@NativeListType{}) ->
			(context, super.elementType) `oneIsA` sub.elementType
		(super@NativeOptionalType{}, sub) ->
			(context, super.falueType) `oneIsA` sub
		(super, sub@NativeOrType{}) ->
			void $ sequence $ map (\subOption -> (context, subOption) `oneIsA` super) sub.options.l
		(super@NativeOrType{}, sub) ->
			void $ sequenceAny $ map ((context, sub) `oneIsA`) super.options.l
		(super, sub) -> Error $ PrimitiveMismatch super sub