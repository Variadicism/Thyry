module Beng.Parse.Patterns.Delimited (
	parse
) where

import Utils.Fallible
import Utils.Messaging (Messagable(..), msg)
import qualified Utils.Maps.Ordered as OMap
import qualified Utils.Populace as P

import Beng.Parse.Patterns (asPattern)
import qualified Beng.Parse.Patterns as Pattern
import Beng.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>:>), (>\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (compareAsSuperDefault)
import Beng.Parse.Parsers.PatternComparator (internallySatisfies)
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Things (NativeSomeType(..), NativeListType(..))
import Beng.Types.Things (SomeThing(..))
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Patterns (
	Argument(..),
	Comparison(..),
	ComparatorState(..),
	Delimited(..),
	Mismatch(..),
	SomePattern(..))

import Data.Map.Ordered ((<>|))

parseDelimited :: Delimited -> Code.Parser Match
parseDelimited self@Delimited{..} = show delimitend ++ " by " ++ show delimiter @+>
	Pattern.parse delimitend >:>
	(Code.parseAll (Pattern.parse delimiter >:> Pattern.parse delimitend) >\> \case
		[] -> Match.DelimitedTailMissing $ OMap.values $ Pattern.getArgs (SomePattern self)
		firstMatch:matchTail -> Match.DelimitedTailMatch $ P.Populace firstMatch matchTail) >\>
	uncurry Match.Delimited

compareAsSubDelimited :: Delimited -> PatternComparator.Parser
compareAsSubDelimited self@Delimited{..} = show delimitend ++ " by " ++ show delimiter ++ " comparator" @> \state -> do
	case state.rest.requirement of
		[] -> Error $ LeftoverSub $ P.assume state.rest.candidate
		next:superLeft -> case asPattern next :: Maybe Delimited of
			Just nextSuper@Delimited{} -> do
				sequence [
					(state, nextSuper.delimitend) `internallySatisfies` delimitend,
					(state, nextSuper.delimiter) `internallySatisfies` delimiter]
				PatternComparator.accept [next] state
			Nothing -> Error $ Mismatch (SomePattern self) $ P.Populace next superLeft

instance Eq Delimited where
	a == b = a.delimiter == b.delimiter && a.delimitend == b.delimitend

instance Show Delimited where
	show = TPattern.showPatternWith False

instance Messagable Delimited where
	msg = show

instance TPattern.Pattern Delimited where
	parse = parseDelimited
	compareAsSub = compareAsSubDelimited
	compareAsSuper self = compareAsSuperDefault (SomePattern self)
	showPatternWith useMsg Delimited{..} =
		"(" ++ (if useMsg then msg delimitend else show delimitend) ++ "){" ++
			(if useMsg then msg delimiter else show delimiter) ++ "}"
	getSubpatterns Delimited{..} = P.Populace delimitend [delimiter]
	mustHavePrefix Delimited{..} = Pattern.mustHavePrefix delimitend
	mustHaveSuffix Delimited{..} = Pattern.mustHaveSuffix delimitend
	canHavePrefix Delimited{..} = Pattern.canHavePrefix delimiter || Pattern.canHavePrefix delimitend
	canHaveSuffix Delimited{..} = Pattern.canHaveSuffix delimiter || Pattern.canHaveSuffix delimitend
	canMatchEmpty Delimited{..} = Pattern.canMatchEmpty delimitend
	startingSpaceStates Delimited{..} = Pattern.startingSpaceStates delimitend
	isOptional Delimited{..} = Pattern.isOptional delimitend
	getArgsUsing getArgs Delimited{..} = do
		let wrapTypes wrapper = OMap.map (\p -> p{ argType = SomeThing $ wrapper p.argType })
		wrapTypes NativeSomeType (getArgs delimiter) <>| wrapTypes NativeListType (getArgs delimitend)

parse :: Delimited -> Code.Parser Match
parse = parseDelimited
