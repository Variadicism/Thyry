module Beng.Parse.Matches.NonPrefixed (
	Match(..)
) where

import Beng.Parse.Matches ()
import Beng.Parse.Types.Matches.NonPrefixed (Match(..))

instance Show Match where
	show Match{..} =
		(if argCaptured then "" else "NO ") ++
		"arg captured in " ++ show match