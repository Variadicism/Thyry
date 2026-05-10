module Beng.Parse.Patterns.NamedText (
	canBeEmpty,
	parse
) where

import Utils.Fallible
import Utils.Lists (wrap)
import Utils.Messaging (Messagable(..), msg)
import qualified Utils.Populace as P

import Beng.Locations ()
import Beng.Parse.Parsers ((@>), (@+>), (>>>), (>:>), (>\>), (>/\>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (
	accept,
	acceptRest,
	comparator,
	internallySatisfies)
import {-# SOURCE #-} Beng.Parse.Matches ()
import qualified Beng.Types.Parse.Matches as Match
import Beng.Parse.Patterns (asPattern)
import qualified Beng.Parse.Patterns as Pattern
import Beng.Things (NativeStringType(..), NativeStringValue(..))
import Beng.Types.Things (SomeParameterizedThing(..), SomeThing(..))
import Beng.Types.Parse.Parsers.PatternComparator (
	Comparator,
	Comparison(..),
	ComparatorState(..))
import qualified Beng.Types.Parse.Patterns as TypePattern
import Beng.Types.Parse.Patterns (
	Argument(..),
	Mismatch(..),
	NamedText(..),
	Pattern,
	SomePattern(..))

import qualified Data.Map as Map
import qualified Data.Map.Ordered as OMap

canBeEmpty :: SomePattern -> Bool
canBeEmpty = Pattern.canMatchEmpty

parseNamedText :: NamedText -> Code.Parser Match.NamedText
parseNamedText NamedText{..} = "named text " ++ wrap "\"" name @+>
	Pattern.parse subpattern >/\> (\s match -> do
		let argument = Match.Argument {
			pattern = Argument {
				decLoc,
				name,
				argType = SomeParameterizedThing NativeStringType },
			matchedType = SomeParameterizedThing NativeStringType,
			parameterMatches = mempty,
			value = SomeThing $ NativeStringValue $ Match.toCode match }
		s{ Code.arguments = Map.insert name argument s.arguments }) >\> \match ->
	Match.NamedText { decLoc, name, match }

compareAsCandidateNamedText :: NamedText -> Comparator
compareAsCandidateNamedText NamedText{..} = "named text " ++ wrap "\"" name ++ " comparator" @> \state ->
	case state.rest.candidate of
		_:candidateLeft -> case state.rest.requirement of
			next:requirementLeft -> case asPattern next :: Maybe NamedText of
				Just nt@NamedText{} -> if nt.name == name then do
						(state, nt.subpattern) `internallySatisfies` subpattern
						accept [next] state
					else
						Error $ Mismatch next $ P.Populace next requirementLeft
				Nothing -> state{ rest = state.rest{ candidate = subpattern : candidateLeft }} >>> comparator
			_ -> state{ rest = state.rest{ candidate = subpattern : candidateLeft }} >>> comparator
		[] -> case state.rest.requirement of
			next:requirementLeft -> do
				let self = NamedText { name, subpattern, decLoc }
				Error $ Mismatch (SomePattern self) $ P.Populace next requirementLeft
			[] -> acceptRest state

compareAsRequirementNamedText :: NamedText -> Comparator
compareAsRequirementNamedText nt@NamedText{..} =
	"named text " ++ wrap "\"" name ++ " requirement comparator" @> \state ->
	case state.rest.candidate of
		nextCandidate:_ -> case asPattern nextCandidate :: Maybe NamedText of
			Just NamedText{} -> dispatchCurrentCandidate nextCandidate state
			Nothing -> exposeSubpattern nt state
		[] -> exposeSubpattern nt state
	where
		dispatchCurrentCandidate (SomePattern pattern) state =
			state >>> TypePattern.compareAsCandidate pattern >:> comparator >\> const ()

		exposeSubpattern NamedText{..} state = case state.rest.requirement of
			_:requirementLeft ->
				state{ rest = state.rest{ requirement = subpattern:requirementLeft }} >>> comparator
			[] -> case state.rest.candidate of
				nextCandidate:candidateLeft -> Error $ LeftoverCandidate $ P.Populace nextCandidate candidateLeft
				[] -> acceptRest state

instance Eq NamedText where
	a == b = a.name == b.name && a.subpattern == b.subpattern && a.decLoc == b.decLoc

instance Show NamedText where
	show NamedText{..} = wrap "\"" name ++ "(" ++ show subpattern ++ ")"

instance Messagable NamedText where
	msg NamedText{..} = wrap "\"" name ++ "(" ++ msg subpattern ++ ")"

instance Pattern Match.NamedText NamedText where
	parse = parseNamedText
	compareAsCandidate = compareAsCandidateNamedText
	compareAsRequirement = compareAsRequirementNamedText
	mustHavePrefix NamedText{..} = not $ canBeEmpty subpattern
	mustHaveSuffix NamedText{..} = Pattern.mustHavePrefix subpattern
	canHavePrefix _ = True
	canHaveSuffix _ = True
	canMatchEmpty NamedText{..} = Pattern.canMatchEmpty subpattern
	startingSpaceStates NamedText{..} = Pattern.startingSpaceStates subpattern
	isOptional NamedText{..} = Pattern.isOptional subpattern
	getSubpatterns NamedText{..} = P.singleton subpattern
	getArgsUsing getArgs NamedText{..} =
		(name, Argument {
			name,
			decLoc,
			argType = SomeParameterizedThing NativeStringType }) OMap.|<
			getArgs subpattern

parse :: NamedText -> Code.Parser Match.NamedText
parse = parseNamedText
