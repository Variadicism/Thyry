module Beng.Parse.Patterns.Or (
	parse,
	parseNonPrefixed
) where

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Types.Matches (Match)
import qualified Beng.Parse.Types.Matches as Match
import qualified Beng.Parse.Types.Matches.NonPrefixed as NonPrefixed
import Beng.Parse.Parsers (Parser, (@+>), (>|>), (>\>))
import Beng.Parse.Types.Patterns (Pattern)
import Beng.Types.Ops (Op)

-- private

parseWith :: (Int -> Pattern -> Parser t) -> [Pattern] -> Parser t
parseWith parserForSubpattern subpatterns =
	(show (length subpatterns) ++ " possible patterns" @+>) $
-- An Or with no subpatterns makes no sense, so `foldl1` should be acceptable.
		foldl1 (>|>) $ map (uncurry parserForSubpattern) $ zip [0..] subpatterns

-- exported

parse :: [Pattern] -> Parser Match
parse subpatterns = flip parseWith subpatterns \matchIndex pattern ->
	Pattern.parse pattern >\>
	\match -> Match.Or { match, matchIndex }

parseNonPrefixed :: [Pattern] -> Op -> Parser NonPrefixed.Match
parseNonPrefixed subpatterns op = flip parseWith subpatterns \matchIndex pattern ->
	Pattern.parseNonPrefixed pattern op >\>
	\npMatch -> npMatch{
		NonPrefixed.match = Match.Or { matchIndex, match = npMatch.match }}