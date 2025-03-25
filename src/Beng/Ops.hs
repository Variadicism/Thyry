module Beng.Ops (
	Op(..),
	isNullary,
	hasPrefix,
	hasSuffix,
	getArgs,
	returnType,
	toCode
) where

import Utils.Messaging (Messagable, msg)

import Beng.Build.Cards ()
import qualified Beng.Ops.Declarations as Declaration
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Matches (Argument)
import Beng.Types.Things (Thing)
import Beng.Types.Ops (Op(..))

import Data.Map.Ordered (OMap)
import Data.Text.Lazy (Text)
import GHC.Records (HasField, getField)

-- instances

deriving instance Eq Op

instance Show Op where
	show Op{..} = show location ++ ": " ++ show match ++ " as " ++ show card

instance Messagable Op where
	msg = msg . match

instance HasField "returnType" Op Thing where
	getField = returnType

-- exports

isNullary :: Op -> Bool
isNullary op = Declaration.isNullary op.card.declaration

hasPrefix :: (Op -> Bool)
hasPrefix = Match.hasPrefix . match

hasSuffix :: (Op -> Bool)
hasSuffix = Match.hasSuffix . match

getArgs :: (Op -> OMap String Argument)
getArgs = Match.getArgs . match

returnType :: Op -> Thing
-- TODO: get the return type from Match when typing becomes formulaic
returnType op = op.card.declaration.returnType

toCode :: (Op -> Text)
toCode = Match.toCode . match
