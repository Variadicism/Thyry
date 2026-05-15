module Beng.Parse.Matches (
	asMatch,
	hasArgs,
	module Beng.Types.Parse.Matches
) where

import Prelude hiding (map, undefined)

import Utils.Collective (map)
import Utils.Fallible (FallibleI(..))
import Utils.Lists (ifNotNull, takeUntilIncl, wrap)
import qualified Utils.Maps.Ordered as OMap
import Utils.Messaging (Messagable, msg, msgList)
import Utils.Populace (Populace(..))
import qualified Utils.Populace as P
import qualified Utils.Populace.Populace2 as P2
import Utils.Tuples (toList2)

import Beng.Build.Context.Builders (declareLiteral)
import Beng.Types.Parse.Matches (
	And(..),
	Argument(..),
	CharClass(..),
	Delimited(..),
	DelimitedTail(..),
	Literal(..),
	Match,
	NamedText(..),
	Or(..),
	SomeMatch(..),
	Space(..))
import qualified Beng.Types.Parse.Matches as Match
import Beng.Things ()
import qualified Beng.Types.Things as Thing
import Beng.Types.Things (SomeConcreteThing(..), SomeThing)
import Beng.Locations ()
import Beng.Types.Invocations (SomeInvocation)
import {-# SOURCE #-} Beng.Parse.Patterns ()
import {-# SOURCE #-} Beng.Parse.Patterns.Literal ()
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Types.Things (
	SomeParameterizedThing(..),
	SomeThing(..),
	NativeStringType(..),
	NativeStringValue(..),
	NativeOptionalType(..),
	NativeOptionalValue(..),
	NativeSomeType(..),
	NativeSomeValue(..),
	NativeListType(..),
	NativeListValue(..),
	One(..),
	Undefined(..))
import Data.Map.Ordered ((<|), (|<), (<>|), OMap)
import qualified Data.Map.Ordered as OMap
import Data.Text.Lazy (pack, unpack)
import qualified Data.Text.Lazy as Text
import Data.Typeable (cast)

instance Eq Argument where
	(==) p1 p2 = p1.pattern.name == p2.pattern.name

instance Show Argument where
	show p@Argument{pattern = Pattern.Argument{decLoc}, ..} = "from " ++ show decLoc ++ ", " ++ msg p

instance Messagable Argument where
	msg Argument{pattern = Pattern.Argument{name, argType}, ..} =
		wrap "'" name ++ ", " ++ show argType ++ " := " ++ show value

deriving instance Eq DelimitedTail

instance Show DelimitedTail where
	show = \case
		DelimitedTailMatch pairs -> show pairs
		DelimitedTailMissing misses -> "[not given" ++ ifNotNull (" for "++) (show misses) ++ "]"

instance Messagable DelimitedTail where
	msg = \case
		DelimitedTailMatch pairs -> msg pairs
		DelimitedTailMissing misses -> "missing tail" ++ ifNotNull (" with "++) (msgList misses)

asMatch :: Match m => SomeMatch -> Maybe m
asMatch (SomeMatch match) = cast match

instance Eq SomeMatch where
	SomeMatch m1 == SomeMatch m2 = maybe False (m1 ==) $ cast m2

instance Show SomeMatch where
	show (SomeMatch match) = unpack $ Match.toCode match

instance Messagable SomeMatch where
	msg (SomeMatch match) = unpack $ Match.toCode match

instance Match SomeMatch where
	getSubmatches (SomeMatch match) = Match.getSubmatches match
	toCode (SomeMatch match) = Match.toCode match
	getArgs (SomeMatch match) = Match.getArgs match
	hasPrefix (SomeMatch match) = Match.hasPrefix match
	hasSuffix (SomeMatch match) = Match.hasSuffix match
	resolve bindings (SomeMatch match) = Match.resolve bindings match

instance Eq Space where
	Space{text = text1} == Space{text = text2} = text1 == text2

instance Show Space where
	show Space{text} = unpack text

instance Messagable Space where
	msg = show

instance Eq Literal where
	Literal{text = text1} == Literal{text = text2} = text1 == text2

instance Show Literal where
	show Literal{text} = unpack text

instance Messagable Literal where
	msg = show

instance Eq CharClass where
	CharClass{char = char1} == CharClass{char = char2} = char1 == char2

instance Show CharClass where
	show CharClass{char} = [char]

instance Messagable CharClass where
	msg = show

instance Eq NamedText where
	match1 == match2 =
		match1.decLoc == match2.decLoc &&
		match1.name == match2.name &&
		match1.match == match2.match

instance Show NamedText where
	show = unpack . Match.toCode

instance Messagable NamedText where
	msg = show

instance Eq Or where
	match1 == match2 = match1.matchIndex == match2.matchIndex

instance Show Or where
	show = unpack . Match.toCode

instance Messagable Or where
	msg = show

instance Eq And where
	And{matches = matches1} == And{matches = matches2} = matches1 == matches2

instance Show And where
	show = unpack . Match.toCode

instance Messagable And where
	msg = show

instance Eq Delimited where
	match1 == match2 = match1.head == match2.head && match1.tail == match2.tail

instance Show Delimited where
	show = unpack . Match.toCode

instance Messagable Delimited where
	msg = show

instance Match Space where
	toCode Space{text} = text
	hasPrefix match = not $ Text.null match.text
	hasSuffix match = not $ Text.null match.text

instance Match Literal where
	toCode Literal{text} = text
	hasPrefix match = not $ Text.null match.text
	hasSuffix match = not $ Text.null match.text

instance Match CharClass where
	toCode CharClass{char} = Text.singleton char
	hasPrefix _ = True
	hasSuffix _ = True

instance Match NamedText where
	toCode NamedText{match = SomeMatch match} = Match.toCode match
	getArgs NamedText{name,decLoc,match = SomeMatch match} = do
		let argument = Argument {
			pattern = Pattern.Argument {
				name,
				decLoc,
				argType = SomeParameterizedThing NativeStringType },
			matchedType = SomeParameterizedThing NativeStringType,
			parameterMatches = mempty,
			value = SomeThing $ NativeStringValue $ Match.toCode match }
		OMap.singleton (name, argument)
	hasPrefix NamedText{match = SomeMatch match} = not $ Text.null $ Match.toCode match
	hasSuffix NamedText{match = SomeMatch match} = not $ Text.null $ Match.toCode match
	resolve bindings NamedText{decLoc, name, match} = do
		resolvedMatch <- Match.resolve bindings match
		return $ SomeMatch NamedText { decLoc, name, match = resolvedMatch }

instance Match Or where
	getSubmatches Or{match} = P.singleton match
	toCode Or{match = SomeMatch match} = Match.toCode match
	getArgs Or{match = SomeMatch match,misses} = do
		let matchFalParam = \decLoc name argType value matchedType -> Argument {
			pattern = Pattern.Argument {
				decLoc,
				name,
				argType = SomeParameterizedThing $ NativeOptionalType argType },
			matchedType = SomeParameterizedThing $ NativeOptionalType matchedType,
			parameterMatches = mempty,
			value = SomeThing $ NativeOptionalValue value }
		let missEntry = \p -> (p.name,
			matchFalParam p.decLoc p.name p.argType
				(Error $ Undefined [("", declareLiteral (pack p.name) p.argType p.decLoc)])
				(SomeParameterizedThing $ NativeOptionalType $ SomeParameterizedThing One))
		let falValue = \p -> matchFalParam p.pattern.decLoc p.pattern.name p.pattern.argType
			(Falue p.value) (SomeParameterizedThing $ NativeOptionalType p.matchedType)

		OMap.fromList (map missEntry misses) <>|
			OMap.map falValue (Match.getArgs match)
	hasPrefix Or{match = SomeMatch match} = Match.hasPrefix match
	hasSuffix Or{match = SomeMatch match} = Match.hasSuffix match
	resolve bindings Or{match, matchIndex, misses} = do
		resolvedMatch <- Match.resolve bindings match
		return $ SomeMatch Or { match = resolvedMatch, matchIndex, misses }

instance Match And where
	getSubmatches And{matches} = matches.p1
	toCode And{matches} = Text.concat $ map Match.toCode matches.l
	getArgs And{matches} = OMap.concat $ P2.map Match.getArgs matches
	hasPrefix And{matches} = any Match.hasPrefix $ takeUntilIncl hasArgs matches.l
	hasSuffix And{matches} = any Match.hasSuffix $ takeUntilIncl hasArgs $ reverse matches.l
	resolve bindings And{matches} = do
		let resolveMatches = \case
				P2.Populace2 first second rest -> do
					resolvedFirst <- Match.resolve bindings first
					resolvedSecond <- Match.resolve bindings second
					resolvedRest <- sequence $ map (Match.resolve bindings) rest
					return $ P2.Populace2 resolvedFirst resolvedSecond resolvedRest
		resolvedMatches <- resolveMatches matches
		return $ SomeMatch And { matches = resolvedMatches }

instance Match Delimited where
	getSubmatches delimited@Delimited{head} = P.Populace head $ case delimited.tail of
		DelimitedTailMatch matchPairs -> concatMap toList2 matchPairs
		DelimitedTailMissing _ -> []
	toCode match = Text.concat $ map Match.toCode $ P.toList $ Match.getSubmatches match
	getArgs delimited@Delimited{head = headMatch,tail = tailMatch} = case tailMatch of
		DelimitedTailMatch _ -> do
			let revalueParam :: Argument -> Populace SomeThing -> Argument = \p values -> p{
				pattern = p.pattern{
					Pattern.argType = SomeParameterizedThing $ NativeSomeType p.pattern.argType },
				matchedType = SomeParameterizedThing $ NativeSomeType p.matchedType,
				value = SomeThing $ NativeSomeValue values }
			let combineValuesByName
					:: Argument -> OMap String (Argument, Populace SomeThing) ->
						OMap String (Argument, Populace SomeThing) =
					\p prevs -> do
				let oldValues = case OMap.lookup p.pattern.name prevs of
					Nothing -> []
					Just (_, values) -> P.toList values
				(p.pattern.name, (p, Populace p.value oldValues)) |< prevs
			let collateArgs :: ([Argument] -> OMap String Argument) =
				OMap.map (uncurry revalueParam) . foldr combineValuesByName OMap.empty
			collateArgs $ concatMap (OMap.values . Match.getArgs) $
				P.toList $ Match.getSubmatches delimited
		DelimitedTailMissing missedParams -> do
			let collateArgsWithMissing
					:: Pattern.Argument -> OMap String Argument -> OMap String Argument =
					\Pattern.Argument{..} matches -> do
				let missingParamMatch = Argument {
					pattern = Pattern.Argument {
						decLoc,
						name,
						argType = SomeParameterizedThing $ NativeListType argType },
					matchedType = SomeParameterizedThing $ NativeListType $ SomeParameterizedThing One,
					parameterMatches = mempty,
					value = SomeThing $ NativeListValue ([] :: [SomeThing]) }
				(name, missingParamMatch) <| matches
			foldr collateArgsWithMissing (Match.getArgs headMatch) missedParams
	hasPrefix match =
		any Match.hasPrefix $ takeUntilIncl hasArgs $ P.toList $ Match.getSubmatches match
	hasSuffix match =
		any Match.hasSuffix $ takeUntilIncl hasArgs $ reverse $ P.toList $ Match.getSubmatches match
	resolve bindings Delimited{head, tail} = do
		resolvedHead <- Match.resolve bindings head
		resolvedTail <- case tail of
			DelimitedTailMissing misses ->
				return $ DelimitedTailMissing misses
			DelimitedTailMatch pairs -> do
				let resolvePair (left, right) = do
						resolvedLeft <- Match.resolve bindings left
						resolvedRight <- Match.resolve bindings right
						return (resolvedLeft, resolvedRight)
				let resolvedPairs = case pairs of
						Populace first rest -> do
							resolvedFirst <- resolvePair first
							resolvedRest <- sequence $ map resolvePair rest
							return $ Populace resolvedFirst resolvedRest
				DelimitedTailMatch <$> resolvedPairs
		return $ SomeMatch Delimited { head = resolvedHead, tail = resolvedTail }

instance Match Argument where
	toCode Argument{value} = Thing.toCode value
	getArgs argument = OMap.singleton (argument.pattern.name, argument)
	hasPrefix _ = False
	hasSuffix _ = False
	resolve bindings Argument{pattern,matchedType,parameterMatches,value} = do
		resolvedType <- case value of
			SomeThing thing -> case cast thing :: Maybe SomeInvocation of
				Just someInvocation ->
					return $ Thing.parameterize someInvocation.returnType
				Nothing -> case Thing.resolve bindings matchedType of
					Falue (SomeConcreteThing concreteThing) ->
						return $ Thing.parameterize concreteThing
					Error _ ->
						return matchedType
		return $ SomeMatch Argument {
			pattern, value, parameterMatches,
			matchedType = resolvedType }
hasArgs :: SomeMatch -> Bool
hasArgs (SomeMatch match) = not $ OMap.null $ Match.getArgs match
