module Beng.Operators.Definitions (
	Definition(..),
	Runner
) where

import Utils.Messaging (Messagable, msg)

import Beng.Locations ()
import Beng.Operators.Declarations ()
import qualified Beng.Operators.Declarations as Dec
import Beng.Types.Operators.Definitions (Definition(..), Runner)

-- instances

instance Eq Definition where
	(==) d1 d2 = d1.location == d2.location

instance Show Definition where
	show definition =
		(if definition.location /= Dec.location definition.declaration
				then show definition.location ++ ": "
				else "") ++
			show definition.declaration

instance Messagable Definition where
	msg Definition{declaration} = msg declaration

instance Ord Definition where
	compare d1 d2 = compare d1.location d2.location
