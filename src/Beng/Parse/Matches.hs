module Beng.Parse.Matches (
	Capture(..),
	Match(..),
	getSubmatches,
	getText,
	getArgs,
	hasArgs,
	hasPrefix,
	hasSuffix
) where

import Utils.Lists (takeUntilIncl, updateAt)
import qualified Utils.Maps.Ordered as OMap
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Tuples (mapSnd2, toList2)

import {-# SOURCE #-} Beng.Ops ()
import Beng.Parse.Types.Matches (Capture(..), Match(..))
import Beng.Types.Ops (Op(..))

import Data.List (findIndex)
import Data.Map.Ordered ((|<>), (<>|), OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (Text, unpack)
import qualified Data.Text.Lazy as Text

-- instances

instance Show Capture where
	show = \case
		OpCapture{op} -> show op
		StringCapture{text} -> show text
		ListCapture{captures} -> show captures
		MaybeCapture{maybeCapture} -> show maybeCapture

instance Eq Match where
	-- Most of these are trivial....
	(==) s1@Space{} s2@Space{} = s1.text == s2.text
	(==) l1@Literal{} l2@Literal{} = l1.text == l2.text
	(==) o1@Or{} o2@Or{} = o1.matchIndex == o2.matchIndex
	(==) a1@And{} a2@And{} = a1.matches == a2.matches
	(==) d1@Delimited{} d2@Delimited{} = d1.head == d2.head && d1.tail == d2.tail
	-- ...But, Argument Matches need to be compared by Definition only.
	-- Otherwise, an import cycle forms for Eq Op. Plus, if the names match, they should match.
	(==) a1@Argument{} a2@Argument{} = a1.name == a2.name
	(==) _ _ = False

instance Show Match where
	show = unpack . getText

-- exports

getSubmatches :: (Match -> Populace Match)
getSubmatches = \case
	Or{match} -> P.singleton match
	And{matches} -> matches
	match@Delimited{} -> P.Populace match.head $ concatMap toList2 match.tail
	match -> P.singleton match

-- This is defined here for use in defining `show Match`.
getText :: (Match -> Text)
getText = \case
	Space{text} -> text
	Literal{text} -> text
	CharClass{char} -> Text.singleton char
	NamedText{match} -> getText match
	Or{match} -> getText match
	And{matches} -> Text.concat $ map getText matches.l
	match@Delimited{} -> Text.concat $ map getText $ P.toList $ getSubmatches match
	Argument{op} -> getText op.match

getArgs :: (Match -> OMap String Capture)
getArgs = \case
	Space{} -> OMap.empty
	Literal{} -> OMap.empty
	CharClass{} -> OMap.empty
	NamedText{name,match} -> OMap.singleton (name, StringCapture $ getText match)
	Or{match,misses} ->
		OMap.map (MaybeCapture . Just) (getArgs match) |<>
		(OMap.fromList $ map (,MaybeCapture Nothing) misses)
	And{matches} -> OMap.concat $ P.map getArgs matches
	Delimited{head=headMatch,tail=tailMatch} -> do
		let delimitendMatches = headMatch : map snd tailMatch
		let delimiterMatches = map fst tailMatch
		let foldInEntry :: (String, Capture) -> [(String, Populace Capture)] ->
				[(String, Populace Capture)] = \(name, capture) entries ->
			case findIndex ((name==) . fst) entries of
				Nothing -> (name, P.singleton capture) : entries
				Just index -> updateAt index (mapSnd2 $ P.cons capture) entries
		let listCapturesByArgNames :: [Match] -> OMap String Capture = \matches -> do
			OMap.fromList $ map (mapSnd2 ListCapture) $
				foldr foldInEntry [] $ concatMap (OMap.assocs . getArgs) matches
		listCapturesByArgNames delimitendMatches <>| listCapturesByArgNames delimiterMatches
	Argument{name,op} -> OMap.singleton (name, OpCapture op)

hasArgs :: (Match -> Bool)
hasArgs = not . OMap.null . getArgs

hasPrefix :: Match -> Bool
hasPrefix = \case
	NamedText{match} -> not $ Text.null $ getText match
	Or{match} -> hasPrefix match
	And{matches} -> any hasPrefix $ takeUntilIncl hasArgs matches.l
	match@Delimited{} -> any hasPrefix $ takeUntilIncl hasArgs $ P.toList $ getSubmatches match
	Argument{} -> False
	match -> not $ Text.null $ getText match

hasSuffix :: Match -> Bool
hasSuffix = \case
	NamedText{match} -> not $ Text.null $ getText match
	Or{match} -> hasSuffix match
	And{matches} -> any hasSuffix $ takeUntilIncl hasArgs $ reverse matches.l
	match@Delimited{} -> any hasSuffix $ takeUntilIncl hasArgs $ reverse $ P.toList $ getSubmatches match
	Argument{} -> False
	match -> not $ Text.null $ getText match