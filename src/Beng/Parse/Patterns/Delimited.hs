module Beng.Parse.Patterns.Delimited (
	parse
) where

import Utils.Fallible
import Utils.Messaging (Messagable(..), msg)
import qualified Utils.Maps.Ordered as OMap
import qualified Utils.Populace as P

import Beng.Parse.Patterns (asPattern)
import qualified Beng.Parse.Patterns as Pattern
import {-# SOURCE #-} Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Parsers ((@>), (@+>), (>:>), (>\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (
	accept,
	compareAsRequirementDefault,
	internallySatisfies)
import Beng.Things (NativeListType(..), NativeSomeType(..))
import Beng.Types.Things (SomeParameterizedThing(..))
import Beng.Types.Parse.Parsers.PatternComparator (
	Comparator,
	Comparison(..),
	ComparatorState(..))
import Beng.Types.Parse.Patterns (
	Argument(..),
	Delimited(..),
	Mismatch(..),
	Pattern(..),
	SomePattern(..))

import Data.Map.Ordered ((<>|))

parseDelimited :: Delimited -> Code.Parser Match.Delimited
parseDelimited self@Delimited{..} = show delimitend ++ " by " ++ show delimiter @+>
	Pattern.parse delimitend >:>
	(Code.parseAll (Pattern.parse delimiter >:> Pattern.parse delimitend) >\> \case
		[] -> Match.DelimitedTailMissing $ OMap.values $ Pattern.getArgs (SomePattern self)
		firstMatch:matchTail -> Match.DelimitedTailMatch $ P.Populace firstMatch matchTail) >\>
	(\(head, tail) -> Match.Delimited { head, tail })

compareAsCandidateDelimited :: Delimited -> Comparator
compareAsCandidateDelimited self@Delimited{..} = show delimitend ++ " by " ++ show delimiter ++ " comparator" @> \state -> do
	case state.rest.requirement of
		[] -> Error $ LeftoverCandidate $ P.assume state.rest.candidate
		next:requirementLeft -> case asPattern next :: Maybe Delimited of
			Just nextRequirement@Delimited{} -> do
				sequence [
					(state, nextRequirement.delimitend) `internallySatisfies` delimitend,
					(state, nextRequirement.delimiter) `internallySatisfies` delimiter]
				accept [next] state
			Nothing -> Error $ Mismatch (SomePattern self) $ P.Populace next requirementLeft

instance Eq Delimited where
	a == b = a.delimiter == b.delimiter && a.delimitend == b.delimitend

instance Show Delimited where
	show Delimited{..} = "(" ++ show delimitend ++ "){" ++ show delimiter ++ "}"

instance Messagable Delimited where
	msg Delimited{..} = "(" ++ msg delimitend ++ "){" ++ msg delimiter ++ "}"

instance Pattern Match.Delimited Delimited where
	parse = parseDelimited
	compareAsCandidate = compareAsCandidateDelimited
	compareAsRequirement self = compareAsRequirementDefault (SomePattern self)
	getSubpatterns Delimited{..} = P.Populace delimitend [delimiter]
	mustHavePrefix Delimited{..} = Pattern.mustHavePrefix delimitend
	mustHaveSuffix Delimited{..} = Pattern.mustHaveSuffix delimitend
	canHavePrefix Delimited{..} = Pattern.canHavePrefix delimiter || Pattern.canHavePrefix delimitend
	canHaveSuffix Delimited{..} = Pattern.canHaveSuffix delimiter || Pattern.canHaveSuffix delimitend
	canMatchEmpty Delimited{..} = Pattern.canMatchEmpty delimitend
	startingSpaceStates Delimited{..} = Pattern.startingSpaceStates delimitend
	isOptional Delimited{..} = Pattern.isOptional delimitend
	getArgsUsing getArgs Delimited{..} = do
		let wrapTypes wrapper =
				OMap.map (\p -> p{ argType = SomeParameterizedThing $ wrapper p.argType })
		wrapTypes NativeSomeType (getArgs delimiter) <>| wrapTypes NativeListType (getArgs delimitend)
