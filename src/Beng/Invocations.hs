module Beng.Invocations (
	Invocation(..),
	SomeInvocation(..),
	isNullary,
	hasPrefix,
	hasSuffix,
	getArgs,
	returnType,
	toCode
) where

import Utils.Messaging (Messagable, msg)

import Beng.Locations ()
import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Types.Operators (Operator)
import qualified Beng.Types.Operators as Ops
import {-# SOURCE #-} qualified Beng.Parse.Matches as Match
import Beng.Types.Things (SomeThing)
import Beng.Types.Invocations (Invocation(..), SomeInvocation(..))
import Beng.Types.Parse.Matches (Argument)

import Data.Map.Ordered (OMap)
import Data.Text.Lazy (Text, unpack)
import GHC.Records (HasField, getField)

-- instances

instance Eq op => Eq (Invocation op) where
	invocation1 == invocation2 =
		invocation1.location == invocation2.location &&
		invocation1.operator == invocation2.operator &&
		Match.toCode invocation1.match == Match.toCode invocation2.match

instance Show op => Show (Invocation op) where
	show Invocation{..} = show location ++ ": " ++ unpack (Match.toCode match) ++ " as " ++ show operator

instance Messagable op => Messagable (Invocation op) where
	msg = unpack . Match.toCode . match

instance Operator op => HasField "returnType" (Invocation op) SomeThing where
	getField invocation = Ops.returnType invocation.operator

instance Show SomeInvocation where
	show (SomeInvocation invocation) = show invocation

instance Messagable SomeInvocation where
	msg (SomeInvocation invocation) = msg invocation

instance Eq SomeInvocation where
	invocation1 == invocation2 = show invocation1 == show invocation2

instance HasField "returnType" SomeInvocation SomeThing where
	getField invocation = returnType invocation

-- exports

isNullary :: SomeInvocation -> Bool
isNullary (SomeInvocation invocation) = not $ Pattern.hasArgs $ Ops.pattern invocation.operator

hasPrefix :: SomeInvocation -> Bool
hasPrefix (SomeInvocation invocation) = Match.hasPrefix invocation.match

hasSuffix :: SomeInvocation -> Bool
hasSuffix (SomeInvocation invocation) = Match.hasSuffix invocation.match

getArgs :: SomeInvocation -> OMap String Argument
getArgs (SomeInvocation invocation) = Match.getArgs invocation.match

returnType :: SomeInvocation -> SomeThing
-- TODO: get the return type from Match when typing becomes formulaic
returnType (SomeInvocation invocation) = Ops.returnType invocation.operator

toCode :: SomeInvocation -> Text
toCode (SomeInvocation invocation) = Match.toCode invocation.match
