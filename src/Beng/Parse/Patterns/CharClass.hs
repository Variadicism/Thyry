module Beng.Parse.Patterns.CharClass (
	specials,
	showClass,
	parse
) where

import Utils.Fallible (FallibleI(Error))
import Utils.Populace (Populace)

import Beng.Errors (parseError)
import Beng.Parse.Parsers ((@>), Parser, takeAs)
import Beng.Parse.Types.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import {-# SOURCE #-} Beng.Parse.Patterns ()
import Beng.Parse.Types.Parsers (State(..))
import Beng.Parse.Types.Patterns (CharRange(..))

import Data.List (isPrefixOf)
import qualified Data.Text.Lazy as Text

-- constants

-- This only lists characters that are special regardless of position.
specials = "{}]-"

-- exported

showClass :: Populace CharRange -> Bool -> String
showClass ranges negate = do
	let contents = concatMap show ranges.l
	let contentsEscaped = if "^" `isPrefixOf` contents
		then '^':contents
		else contents
	"[" ++ (if negate then "^" else "") ++ contentsEscaped ++ "]"

parse :: Populace CharRange -> Bool -> Parser Match
parse ranges negate = "parse " ++ shown @> \state ->
	case Text.uncons state.rest of
		Nothing -> Error $ parseError state $ shown ++ " was expected, but the end was reached!"
		Just (firstChar, _) -> do
			let inRange :: Char -> CharRange -> Bool = \char CharRange{start,end} ->
				char >= start && char <= end
			let matchesContent = any (inRange firstChar) ranges
			let matches = matchesContent /= negate
			if matches
				then takeAs (Text.singleton firstChar) (Match.CharClass firstChar) state
				else Error $ parseError state $
					shown ++ " was expected, but '" ++ [firstChar] ++ "' was found!"
	where shown = showClass ranges negate