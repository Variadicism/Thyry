module Beng.Parse.Patterns.Delimited (
	parse,
	parseNonPrefixed
) where

import Utils.Tuples (map2)

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import qualified Beng.Parse.Types.Matches.NonPrefixed as NP
import Beng.Parse.Parsers ((>:>), (>:\>), (>^\>), (>\>), (@+>), Parser, parseWhile)
import Beng.Parse.Types.Patterns (Pattern)
import Beng.Types.Ops (Op)

import Data.List (singleton)

-- private

parseTail :: Pattern -> Pattern -> Parser [(Match, Match)]
parseTail delimiter delimitend =
	parseWhile $ Pattern.parse delimiter >:> Pattern.parse delimitend

-- exported

parse :: Pattern -> Pattern -> Parser Match
parse delimiter delimitend =
	"a delimited pattern" @+>
	Pattern.parse delimitend >:>
	parseTail delimiter delimitend >\>
	\(headMatch, tailMatch) -> Match.Delimited headMatch tailMatch

parseNonPrefixed :: Pattern -> Pattern -> Op -> Parser NP.Match
parseNonPrefixed delimiter delimitend op =
	"a delimited pattern non-prefixed" @+>
	Pattern.parseNonPrefixed delimitend op >:\>
	parseNPTail [] >\>
	\(headNPMatch, tailNPMatch) -> do
		let argCaptured = headNPMatch.argCaptured || NP.argCaptured (snd $ last tailNPMatch)
		let match = Match.Delimited headNPMatch.match $ map (map2 NP.match) tailNPMatch
		NP.Match { argCaptured, match }
	where
		parseNPTail :: [(NP.Match, NP.Match)] -> NP.Match -> Parser [(NP.Match, NP.Match)]
		parseNPTail previousTail headMatch = do
			let continue = if headMatch.argCaptured
				then parseTail delimiter delimitend >\> map (map2 wrapMatchNP)
				else
					parseNPTailPair >\> singleton >^\> \nextTailPair ->
					parseNPTail (previousTail ++ nextTailPair) headMatch
			continue >\> (previousTail++)

		parseNPTailPair :: Parser (NP.Match, NP.Match)
		parseNPTailPair =
			Pattern.parseNonPrefixed delimiter op >:\> \delimiterMatch ->
				if delimiterMatch.argCaptured
					then Pattern.parse delimitend >\> wrapMatchNP
					else Pattern.parseNonPrefixed delimitend op

		wrapMatchNP :: Match -> NP.Match
		wrapMatchNP match = NP.Match { match, argCaptured = True }