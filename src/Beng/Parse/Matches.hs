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
import Utils.Maps (mapOmap)
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

getSubmatches :: (Match -> [Match])
getSubmatches = \case
	Or{match} -> [match]
	And{matches} -> matches
	match@Delimited{} -> match.head : concatMap toList2 match.tail
	match -> [match]

-- This is defined here for use in defining `show Match`.
getText :: (Match -> Text)
getText = \case
	Space{text} -> text
	Literal{text} -> text
	CharClass{char} -> Text.singleton char
	NamedText{match} -> getText match
	Or{match} -> getText match
	And{matches} -> Text.concat $ map getText matches
	match@Delimited{} -> Text.concat $ map getText $ getSubmatches match
	Argument{op} -> getText op.match

getArgs :: (Match -> OMap String Capture)
getArgs = \case
	Space{} -> OMap.empty
	Literal{} -> OMap.empty
	CharClass{} -> OMap.empty
	NamedText{name,match} -> OMap.singleton (name, StringCapture $ getText match)
	Or{match,misses} ->
		mapOmap (MaybeCapture . Just) (getArgs match) |<>
		(OMap.fromList $ map (,MaybeCapture Nothing) misses)
	And{matches} -> foldl (<>|) OMap.empty $ map getArgs matches
	Delimited{head=headMatch,tail=tailMatch} -> do
		let delimitendMatches = headMatch : map snd tailMatch
		let delimiterMatches = map fst tailMatch
		let listCapturesByArgNames :: [Match] -> OMap String Capture = \matches -> do
			let foldInEntry :: [(String, [Capture])] -> (String, Capture) -> [(String, [Capture])] =
				\entries (name, capture) -> case findIndex ((name==) . fst) entries of
					Nothing -> entries ++ [(name, [capture])]
					Just index -> updateAt index (mapSnd2 (++[capture])) entries
			OMap.fromList $ map (mapSnd2 ListCapture) $
				foldl foldInEntry [] $ concatMap (OMap.assocs . getArgs) matches
		listCapturesByArgNames delimitendMatches <>| listCapturesByArgNames delimiterMatches
	Argument{name,op} -> OMap.singleton (name, OpCapture op)

hasArgs :: (Match -> Bool)
hasArgs = not . OMap.null . getArgs

hasPrefix :: Match -> Bool
hasPrefix = \case
	NamedText{match} -> not $ Text.null $ getText match
	Or{match} -> hasPrefix match
	And{matches} -> any hasPrefix $ takeUntilIncl hasArgs matches
	match@Delimited{} -> any hasPrefix $ takeUntilIncl hasArgs $ getSubmatches match
	Argument{} -> False
	match -> not $ Text.null $ getText match

hasSuffix :: Match -> Bool
hasSuffix = \case
	NamedText{match} -> not $ Text.null $ getText match
	Or{match} -> hasSuffix match
	And{matches} -> any hasSuffix $ takeUntilIncl hasArgs $ reverse matches
	match@Delimited{} -> any hasSuffix $ takeUntilIncl hasArgs $ reverse $ getSubmatches match
	Argument{} -> False
	match -> not $ Text.null $ getText match