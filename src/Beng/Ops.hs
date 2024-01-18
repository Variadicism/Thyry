module Beng.Ops (
	Op(..),
	isNullary,
	hasPrefix,
	hasSuffix,
	getArgs
) where

import Beng.Build.Cards ()
import qualified Beng.Ops.Declarations as Declaration
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Matches (Capture)
import Beng.Types.Ops (Op(..))

import Data.Map.Ordered (OMap)

-- instances

deriving instance Eq Op

instance Show Op where
	show = show . match

-- exports

isNullary :: Op -> Bool
isNullary op = Declaration.isNullary op.card.declaration

hasPrefix :: (Op -> Bool)
hasPrefix = Match.hasPrefix . match

hasSuffix :: (Op -> Bool)
hasSuffix = Match.hasSuffix . match

getArgs :: (Op -> OMap String Capture)
getArgs = Match.getArgs . match