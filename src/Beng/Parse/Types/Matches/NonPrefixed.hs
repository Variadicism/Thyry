module Beng.Parse.Types.Matches.NonPrefixed (
	Match(..)
) where

import qualified Beng.Parse.Types.Matches as Pattern

data Match = Match {
	match :: Pattern.Match,
	argCaptured :: Bool }