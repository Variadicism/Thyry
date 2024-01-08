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

import qualified Beng.Parse.Arguments as Arg
import Beng.Parse.Types.Matches (Match(..))
import Beng.Types.Ops (Op(..))

import Data.Text.Lazy (Text, unpack)
import qualified Data.Text.Lazy as Text

-- instances

deriving instance Eq Match

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
	Argument{arg} -> getText arg.op.match

getArgs :: (Match -> [Arg.Match])
getArgs = \case
	Space{} -> []
	Literal{} -> []
	Or{match} -> getArgs match
	And{matches} -> concatMap getArgs matches
	match@Delimited{} -> concatMap getArgs $ getSubmatches match
	Argument{arg} -> [arg]

hasArgs :: (Match -> Bool)
hasArgs = not . null . getArgs

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