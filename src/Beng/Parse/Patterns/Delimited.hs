module Beng.Parse.Patterns.Delimited (
	parse,
	compareFrom
) where

import Utils.Fallible
import qualified Utils.Maps.Ordered as OMap
import qualified Utils.Populace as P

import {-# SOURCE #-} qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Parse.Parsers ((@>), (@+>), (>:>), (>\>))
import {-# SOURCE #-} Beng.Parse.Patterns (satisfies)
import qualified Beng.Parse.Parsers.Code as Code
import qualified Beng.Parse.Parsers.PatternComparator as PC
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Patterns (Mismatch(..), Pattern(..))

-- exported

parse :: Pattern -> Pattern -> Code.Parser Match
parse delimiter delimitend = show delimitend ++ " by " ++ show delimiter @+>
	Pattern.parse delimitend >:>
	(Code.parseAll (Pattern.parse delimiter >:> Pattern.parse delimitend) >\> \case
		[] -> Match.DelimitedTailMissing $ OMap.values $
			Pattern.getArgs $ Pattern.Delimited delimiter delimitend
		firstMatch:matchTail -> Match.DelimitedTailMatch $ P.Populace firstMatch matchTail) >\>
	uncurry Match.Delimited

compareFrom :: Pattern -> Pattern -> PatternComparator.Parser
compareFrom delimiter delimitend = show delimitend ++ " by " ++ show delimiter ++ " comparator" @> \state -> do
	let self = Delimited { delimiter, delimitend }
	case state.rest.super of
		-- Sub must start with the current pattern, so P.assume is safe.
		[] -> Error $ LeftoverSub $ P.assume state.rest.sub
		nextSuper@Delimited{}:_ -> do
			(state.context, nextSuper.delimitend) `satisfies` delimitend
			(state.context, nextSuper.delimiter) `satisfies` delimiter
			PC.accept [nextSuper] state
		nextSuper:superLeft -> Error $ Mismatch self $ P.Populace nextSuper superLeft