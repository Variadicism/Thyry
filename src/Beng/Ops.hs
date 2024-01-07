module Beng.Ops (
	Op(..),
	PreOp(..),
	hasPrefix,
	hasSuffix,
	getArgs,
	showParens
) where

import Prelude hiding (lookup)

import Utils.Lists (wrap)

import qualified Beng.Ops.Definitions as Definition
import qualified Beng.Parse.Types.Arguments as Arg
import qualified Beng.Parse.Matches as Match
import Beng.Types.Ops (Op(..), PreOp(..))

import Data.Map (Map)
import qualified Data.Map as Map
import Data.Text.Lazy (unpack)

-- instances

instance Show PreOp where
	show preop = wrap "'" preop.name ++ " := " ++
		wrap "`" (unpack preop.content)

instance Show Op where
	show op = Definition.showWith (getArgs op) op.definition where

-- exports

hasPrefix :: Op -> Bool
hasPrefix = Match.hasPrefix . match

hasSuffix :: Op -> Bool
hasSuffix = Match.hasSuffix . match

getArgs :: Op -> Map String Op
getArgs op = Map.fromList $ map (\arg -> (arg.definition.name, arg.op)) $ Match.getArgs op.match

showParens :: Op -> String
showParens op = flip Definition.showWithStrings op.definition $
	Map.map (\argOp -> "(" ++ show argOp ++ ")") $ getArgs op