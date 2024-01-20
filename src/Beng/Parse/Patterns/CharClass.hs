module Beng.Parse.Patterns.CharClass (
	specials,
	showClass,
	parse
) where

import Utils.Strings (escape)

import Beng.Parse.Parsers ((@>), Parser, takeAs, takeNone)
import Beng.Parse.Types.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import {-# SOURCE #-} Beng.Parse.Patterns ()
import Beng.Parse.Types.Parsers (State(..))
import Beng.Parse.Types.Patterns (CharRange(..))

import Data.List (isPrefixOf)
import Data.List.Extra (dropEnd, replace)
import qualified Data.Text.Lazy as Text

-- constants

-- This only lists characters that are special regardless of position.
specials = "{}]"

-- exported

showClass :: [CharRange] -> [Char] -> Bool -> String
showClass ranges chars negate = do
	let charsMostlyEscaped = escape specials chars
	let escapeDash = replace "-" "\\-"
	let charsEscaped = if null charsMostlyEscaped || last charsMostlyEscaped /= '-'
		then escapeDash charsMostlyEscaped
		else escapeDash (dropEnd 1 charsMostlyEscaped) ++ "-"
	let contents = concatMap show ranges ++ charsEscaped
	let contentsEscaped = if "^" `isPrefixOf` contents
		then '^':contents
		else contents
	"[" ++ (if negate then "^" else "") ++ contentsEscaped ++ "]"

parse :: [CharRange] -> [Char] -> Bool -> Parser Match
parse ranges chars negate = "parse " ++ showClass ranges chars negate @> \state ->
	case Text.uncons state.rest of
		Nothing -> takeNone state
		Just (firstChar, _) -> do
			let inRange :: Char -> CharRange -> Bool = \char CharRange{start,end} ->
				char >= start && char <= end
			let matchesContent = firstChar `elem` chars || any (inRange firstChar) ranges
			let matches = matchesContent /= negate
			if matches
				then takeAs (Text.singleton firstChar) (Match.CharClass firstChar) state
				else takeNone state