module Beng.Parse.Matches (
	DelimitedTail(..),
	Match(..),
	Argument(..),
	getSubmatches,
	toCode,
	getArgs,
	hasArgs,
	hasPrefix,
	hasSuffix
) where

import Prelude hiding (map, undefined)

import Utils.Collective (map)
import Utils.Fallible (FallibleI(..))
import Utils.Lists (ifNotNull,  takeUntilIncl, wrap)
import qualified Utils.Maps.Ordered as OMap
import Utils.Messaging (Messagable, msg, msgList)
import Utils.Populace (Populace(..))
import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2
import Utils.Tuples (toList2)

import Beng.Build.Context.Builders (declareLiteral)
import Beng.Types.Parse.Matches (Argument(..), DelimitedTail(..), Match(..))
import {-# SOURCE #-} Beng.Parse.Patterns ()
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Things (
	SomeThing(..),
	NativeStringType(..),
	NativeStringValue(..),
	NativeOptionalType(..),
	NativeOptionalValue(..),
	NativeSomeType(..),
	NativeSomeValue(..),
	NativeListType(..),
	NativeListValue(..) )
import {-# SOURCE #-} qualified Beng.Things as Thing

import Data.Map.Ordered ((<|), (|<), (<>|), OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (Text, pack, unpack)
import qualified Data.Text.Lazy as Text

-- instances

instance Eq Argument where
	(==) p1 p2 = p1.name == p2.name

instance Show Argument where
	show p@Argument{..} = "from " ++ show decLoc ++ ", " ++ msg p

instance Messagable Argument where
	msg Argument{..} = wrap "'" name ++ ", " ++ show argType ++ " := " ++ show value

deriving instance Eq DelimitedTail

instance Show DelimitedTail where
	show = \case
		DelimitedTailMatch pairs -> show pairs
		DelimitedTailMissing misses -> "[not given" ++ ifNotNull (" for "++) (show misses) ++ "]"

instance Messagable DelimitedTail where
	msg = \case
		DelimitedTailMatch pairs -> msg pairs
		DelimitedTailMissing misses -> "missing tail" ++ ifNotNull (" with "++) (msgList misses)

instance Eq Match where
	-- Most of these are trivial....
	(==) s1@Space{} s2@Space{} = s1.text == s2.text
	(==) l1@Literal{} l2@Literal{} = l1.text == l2.text
	(==) o1@Or{} o2@Or{} = o1.matchIndex == o2.matchIndex
	(==) a1@And{} a2@And{} = a1.matches == a2.matches
	(==) d1@Delimited{} d2@Delimited{} = d1.head == d2.head && d1.tail == d2.tail
	-- ...But, ArgumentMatches need to be compared by Definition only.
	-- Otherwise, an import cycle forms for Eq Op. Plus, if the names match, they should match.
	(==) (ArgM a1) (ArgM a2) = a1.name == a2.name
	(==) _ _ = False

instance Show Match where
	show = unpack . toCode  -- TODO: include the information than toCode can't.

instance Messagable Match where
	msg = unpack . toCode

-- exports

getSubmatches :: (Match -> Populace Match)
getSubmatches = \case
	Or{match} -> P.singleton match
	And{matches} -> matches.p1
	match@Delimited{} -> P.Populace match.head $ case match.tail of
		DelimitedTailMatch matchPairs -> concatMap toList2 matchPairs
		DelimitedTailMissing _ -> []
	match -> P.singleton match

-- This is defined here for use in defining `show Match`.
toCode :: (Match -> Text)
toCode = \case
	Space{text} -> text
	Literal{text} -> text
	CharClass{char} -> Text.singleton char
	NamedText{match} -> toCode match
	Or{match} -> toCode match
	And{matches} -> Text.concat $ map toCode matches.l
	match@Delimited{} -> Text.concat $ map toCode $ P.toList $ getSubmatches match
	ArgM Argument{value} -> Thing.toCode value

getArgs :: (Match -> OMap String Argument)
getArgs = \case
	Space{} -> OMap.empty
	Literal{} -> OMap.empty
	CharClass{} -> OMap.empty
	NamedText{name,decLoc,match} -> do
		let argument = Argument { name, decLoc,
			argType = SomeThing NativeStringType,
			value = SomeThing $ NativeStringValue $ toCode match }
		OMap.singleton (name, argument)
	Or{match,misses} -> do
		let matchFalParam = \decLoc name argType value -> Argument {
			decLoc, name,
			argType = SomeThing $ NativeOptionalType argType,
			-- These wrappers are ridiculous, but it's the best way I can find in Haskell.
			-- With op type disambiguation, structural typing, and implicit conversion, Beng should stop this.
			value = SomeThing $ NativeOptionalValue value }
		let missEntry = \p -> (p.name,
			matchFalParam p.decLoc p.name p.argType $
				Thing.undefined $ declareLiteral (pack p.name) p.argType p.decLoc)
		let falValue = \p -> matchFalParam p.decLoc p.name p.argType $ Falue p.value

		OMap.fromList (map missEntry misses) <>|
			OMap.map falValue (getArgs match)
	And{matches} -> OMap.concat $ P2.map getArgs matches
	delimited@Delimited{head=headMatch,tail=tailMatch} -> case tailMatch of
		DelimitedTailMatch _ -> do
			let revalueParam :: Argument -> Populace SomeThing -> Argument = \p values -> p{
				argType = SomeThing $ NativeSomeType p.argType,
				value = SomeThing $ NativeSomeValue values }
			let combineValuesByName
					:: Argument -> OMap String (Argument, Populace SomeThing) ->
						OMap String (Argument, Populace SomeThing) =
					\p prevs -> do
				let oldValues = case OMap.lookup p.name prevs of
					Nothing -> []
					Just (_, values) -> P.toList values
				(p.name, (p, Populace p.value oldValues)) |< prevs
			let collateArgs :: ([Argument] -> OMap String Argument) =
				OMap.map (uncurry revalueParam) . foldr combineValuesByName OMap.empty
			collateArgs $ concatMap (OMap.values . getArgs) $ P.toList $ getSubmatches delimited
		DelimitedTailMissing missedParams -> do
			let collateArgsWithMissing
					:: Pattern.Argument -> OMap String Argument -> OMap String Argument =
					\Pattern.Argument{..} matches -> do
				let missingParamMatch = Argument { decLoc, name,
					argType = SomeThing $ NativeListType argType,
					value = SomeThing $ NativeListValue [] }
				(name, missingParamMatch) <| matches
			foldr collateArgsWithMissing (getArgs headMatch) missedParams
	ArgM argument -> OMap.singleton (argument.name, argument)

hasArgs :: (Match -> Bool)
hasArgs = not . OMap.null . getArgs

hasPrefix :: Match -> Bool
hasPrefix = \case
	NamedText{match} -> not $ Text.null $ toCode match
	Or{match} -> hasPrefix match
	And{matches} -> any hasPrefix $ takeUntilIncl hasArgs matches.l
	match@Delimited{} -> any hasPrefix $ takeUntilIncl hasArgs $ P.toList $ getSubmatches match
	ArgM{} -> False
	match -> not $ Text.null $ toCode match

hasSuffix :: Match -> Bool
hasSuffix = \case
	NamedText{match} -> not $ Text.null $ toCode match
	Or{match} -> hasSuffix match
	And{matches} -> any hasSuffix $ takeUntilIncl hasArgs $ reverse matches.l
	match@Delimited{} -> any hasSuffix $ takeUntilIncl hasArgs $ reverse $ P.toList $ getSubmatches match
	ArgM{} -> False
	match -> not $ Text.null $ toCode match
