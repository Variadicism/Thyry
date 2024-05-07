module Beng.Ops (
	Op(..),
	isNullary,
	hasPrefix,
	hasSuffix,
	getArgs,
	toCode
) where

import Utils.Messaging (Messagable, msg)

import Beng.Build.Cards ()
import qualified Beng.Ops.Declarations as Declaration
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Matches (Parameter)
import Beng.Types.Ops (Op(..))

import Data.Map.Ordered (OMap)
import Data.Text.Lazy (Text)

-- instances

deriving instance Eq Op

instance Show Op where
	show Op{..} = show location ++ ": " ++ show match ++ " as " ++ show card

instance Messagable Op where
	msg = msg . match

-- exports

isNullary :: Op -> Bool
isNullary op = Declaration.isNullary op.card.declaration

hasPrefix :: (Op -> Bool)
hasPrefix = Match.hasPrefix . match

hasSuffix :: (Op -> Bool)
hasSuffix = Match.hasSuffix . match

getArgs :: (Op -> OMap String Parameter)
getArgs = Match.getArgs . match

toCode :: (Op -> Text)
toCode = Match.toCode . match