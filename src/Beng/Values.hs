module Beng.Values (
	Type(..),
	Value(..),
	toCode,
	undefined
) where

import Prelude hiding (undefined)

import Utils.Fallible (FallibleI(..), IsError, (<!>), fallible, prepend)
import Utils.Lists (ifNotNull, showWithAnd, wrap)
import Utils.Messaging (Messagable, msg, msgList)
import Utils.Tuples (mapFst2, toList2)

import Beng.Build.Cards ()
import Beng.Ops ()
import qualified Beng.Ops as Op
import Beng.Types.Ops.Declarations (Declaration)
import Beng.Types.Values (Type(..), Undefined(..), Value(..))

import qualified Data.ByteString as BS
import Data.List (intercalate)
import Data.List.Extra (takeEnd)
import Data.Map (assocs)
import Data.Text.Lazy (Text, pack)
import qualified Data.Text.Lazy as Text
import Numeric (showHex)

-- instances

deriving instance Eq Undefined

instance Show Undefined where
	show Undefined{decsByContext} = intercalate "\n" $
		map (\(context, declaration) -> context ++ show declaration ++ " :/=") decsByContext

instance Messagable Undefined where
	msg = show

instance IsError Undefined where
	prepend context Undefined{decsByContext} = Undefined $ map (mapFst2 (context++)) decsByContext
	(<!>) u1 u2 = Undefined $ u1.decsByContext ++ u2.decsByContext

deriving instance Eq Type

instance Show Type where
	show = \case
		ThingType -> "thing"
		TypeType -> "type"
		BitsType{size} -> show size ++ " bits"
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
		NativeCharType -> "native char"
		NativeStringType -> "native string"
		NativeListType{elementType} -> "native list of " ++ show elementType  -- TODO: pluralize elementType
		NativeSomeType{elementType} -> "native some " ++ show elementType  -- TODO: pluralize
		NativeOptionalType{falueType} -> "native " ++ show falueType ++ "?"

instance Messagable Type where
	msg = show

deriving instance Eq Value

instance Show Value where
	show = \case
		ThingValue{definitions} -> show definitions
		TypeValue{parents,properties} -> "type" ++
			ifNotNull (" of "++) (show parents) ++
			ifNotNull (" with "++) (show properties)
		BitsValue{bytes} ->
			"0x" ++ concatMap (\b -> takeEnd 2 $ '0':showHex b "") (BS.unpack bytes)
		OpValue op -> show op
		DefinitionValue def -> show def
		DeclarationValue dec -> show dec
		PatternValue pattern -> show pattern
		NativeCharValue{char} -> wrap "'" [char]
		NativeStringValue{text} -> show text
		NativeListValue{values} -> show values
		NativeSomeValue{valuesP} -> show valuesP
		NativeOptionalValue{fal} -> show fal

instance Messagable Value where
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

toCode :: Value -> Text
toCode = \case
	-- TODO: replace most "pack $ show"s with their own toCodes (and probably a class).
	ThingValue{definitions} -> Text.concat ["a thing where ", pack (msg definitions)]
	tv@TypeValue{} -> pack $ show tv
	BitsValue{bytes} -> pack $ show bytes  -- TODO: probably replace with hex digits
	OpValue op -> Op.toCode op
	DefinitionValue def -> pack $ show def
	DeclarationValue dec -> pack $ show dec
	PatternValue pat -> pack $ show pat
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

undefined :: Declaration -> FallibleI Undefined Value
undefined declaration = Error $ Undefined [("", declaration)]