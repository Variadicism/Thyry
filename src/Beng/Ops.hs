module Beng.Ops (
	Op(..),
	PreOp(..),
	isNullary,
	hasPrefix,
	hasSuffix,
	getArgs
) where

import Prelude hiding (lookup)

import Utils.Lists (wrap)

import Beng.Build.Cards ()
import qualified Beng.Ops.Declarations as Declaration
import qualified Beng.Parse.Matches as Match
import Beng.Types.Ops (Op(..), PreOp(..))

import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (unpack)

-- instances

deriving instance Eq PreOp

instance Show PreOp where
	show preop = wrap "'" preop.name ++ " := " ++
		wrap "`" (unpack preop.content)

deriving instance Eq Op

instance Show Op where
	show op = Declaration.showParensWith (OMap.toMap $ getArgs op) op.card.declaration

-- exports

isNullary :: Op -> Bool
isNullary op = Declaration.isNullary op.card.declaration

hasPrefix :: (Op -> Bool)
hasPrefix = Match.hasPrefix . match

hasSuffix :: (Op -> Bool)
hasSuffix = Match.hasSuffix . match

getArgs :: (Op -> OMap String Op)
getArgs = Match.getArgs . match