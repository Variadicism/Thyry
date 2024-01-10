module Beng.Parse.Matches (
	Match(..),
	getSubmatches,
	getText,
	getArgs,
	hasArgs,
	hasPrefix,
	hasSuffix
) where

import Utils.Lists (takeUntilIncl)
import Utils.Tuples (toList2)

import Beng.Parse.Types.Matches (Match(..))
import Beng.Types.Ops (Op(..))

import Data.Map.Ordered ((<>|), OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (Text, unpack)
import qualified Data.Text.Lazy as Text

-- instances

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
	Or{match} -> getText match
	And{matches} -> Text.concat $ map getText matches
	match@Delimited{} -> Text.concat $ map getText $ getSubmatches match
	Argument{op} -> getText op.match

getArgs :: (Match -> OMap String Op)
getArgs = \case
	Space{} -> OMap.empty
	Literal{} -> OMap.empty
	Or{match} -> getArgs match
	And{matches} -> foldOMaps $ map getArgs matches
	match@Delimited{} -> foldOMaps $ map getArgs $ getSubmatches match
	Argument{name,op} -> OMap.fromList [(name, op)]
	where
		foldOMaps :: [OMap String Op] -> OMap String Op
		foldOMaps = foldl (<>|) OMap.empty

hasArgs :: (Match -> Bool)
hasArgs = not . OMap.null . getArgs

hasPrefix :: Match -> Bool
hasPrefix = \case
	Or{match} -> hasPrefix match
	And{matches} -> any hasPrefix $ takeUntilIncl hasArgs matches
	match@Delimited{} -> any hasPrefix $ takeUntilIncl hasArgs $ getSubmatches match
	Argument{} -> False
	match -> not $ Text.null $ getText match

hasSuffix :: Match -> Bool
hasSuffix = \case
	Or{match} -> hasSuffix match
	And{matches} -> any hasSuffix $ takeUntilIncl hasArgs $ reverse matches
	match@Delimited{} -> any hasSuffix $ takeUntilIncl hasArgs $ reverse $ getSubmatches match
	Argument{} -> False
	match -> not $ Text.null $ getText match