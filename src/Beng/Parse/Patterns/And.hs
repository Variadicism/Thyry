module Beng.Parse.Patterns.And (
	parse,
	parseNonPrefixed
) where

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import qualified Beng.Parse.Types.Matches.NonPrefixed as NP
import Beng.Parse.Parsers ((@+>), (>:>), (>:\>), (>\>), Parser)
import Beng.Parse.Types.Patterns (Pattern)
import Beng.Types.Ops (Op)

import Data.List (singleton)

-- private

parseAsList :: [Pattern] -> Parser [Match]
parseAsList = \case
	[] -> error "An And pattern must have at least one subpattern!"
	[next] -> Pattern.parse next >\> singleton
	(next:rest) ->
		Pattern.parse next >:>
		parseAsList rest >\>
		\(nextMatch, restMatches) -> nextMatch:restMatches

-- exported

parse :: [Pattern] -> Parser Match
parse subpatterns =
	show (length subpatterns) ++ " patterns" @+>
	parseAsList subpatterns >\> Match.And

parseNonPrefixed :: [Pattern] -> Op -> Parser NP.Match
parseNonPrefixed subpatterns op =
	show (length subpatterns) ++ " patterns non-prefixed" @+>
	parseNonPrefixed' subpatterns >\>
	\npMatches -> NP.Match {
		NP.argCaptured = any NP.argCaptured npMatches,
		NP.match = Match.And $ map NP.match npMatches }
	where
		parseNonPrefixed' :: [Pattern] -> Parser [NP.Match]
		parseNonPrefixed' = \case
			[] -> error "An And pattern must have at least one subpattern!"
			[next] -> Pattern.parseNonPrefixed next op >\> singleton
			(next:rest) ->
				Pattern.parseNonPrefixed next op >:\> 
				(\NP.Match{..} ->
					if argCaptured then
						parseAsList rest >\> \matches ->
							flip map matches \match -> NP.Match { argCaptured = True, match }
					else parseNonPrefixed' rest) >\>
				\(nextMatch, restMatches) -> nextMatch:restMatches