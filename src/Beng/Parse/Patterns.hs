module Beng.Parse.Patterns (
	specials,
	asPattern,
	parse,
	getSubpatterns,
	getArgs,
	getNonStructuralArgs,
	getRequiredArgs,
	getOrArgsUsing,
	hasArgs,
	mustHavePrefix,
	mustHaveSuffix,
	canHavePrefix,
	canHaveSuffix,
	canMatchEmpty,
	startingSpaceStates,
	isOptional,
	satisfies,
	module Beng.Types.Parse.Patterns
) where

import Utils.Fallible
import qualified Utils.Maps.Ordered as OMap
import Utils.Messaging (Messagable, debugM, msg)
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (Populace2)
import qualified Utils.Populace.Populace2 as P2
import Utils.Strings (escape)

import Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import {-# SOURCE #-} Beng.Parse.Patterns.And ()
import {-# SOURCE #-} Beng.Parse.Patterns.Arg ()
import {-# SOURCE #-} qualified Beng.Parse.Patterns.CharClass as CharClass
import {-# SOURCE #-} Beng.Parse.Patterns.Delimited ()
import {-# SOURCE #-} Beng.Parse.Patterns.Literal ()
import {-# SOURCE #-} Beng.Parse.Patterns.NamedText ()
import {-# SOURCE #-} Beng.Parse.Patterns.Or ()
import {-# SOURCE #-} Beng.Parse.Patterns.Space ()
import Beng.Parse.Patterns.Arg (msgArg, showArg)
import Beng.Types.Parse.Patterns (
	And(..),
	ArgP(..),
	Argument(..),
	CharClass(..),
	CharRange(..),
	Delimited(..),
	Literal(..),
	Mismatch(..),
	NamedText(..),
	Or(..),
	SomePattern(..),
	Space(..))
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Parse.Parsers ((>>>))
import qualified Beng.Parse.Parsers.Code as Code
import {-# SOURCE #-} qualified Beng.Parse.Parsers.PatternComparator as PC
import {-# SOURCE #-} qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Build.TypeTest (TypeTest)
import Beng.Types.Parse.Matches (Match)
import Beng.Types.Things (Thing(..))

import Data.Map.Ordered (OMap)
import qualified Data.Map.Ordered as OMap
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Typeable (cast)

specials = ".{}[] "

instance Eq SomePattern where
	SomePattern p1 == SomePattern p2 = maybe False (p1 ==) $ cast p2

instance Show SomePattern where
	show (SomePattern p) = TPattern.showPatternWith False p

instance Messagable SomePattern where
	msg (SomePattern p) = TPattern.showPatternWith True p

asPattern :: TPattern.Pattern p => SomePattern -> Maybe p
asPattern (SomePattern p) = cast p

patConcat :: [SomePattern] -> SomePattern
patConcat = \case
	[] -> SomePattern $ Literal ""
	[solo] -> solo
	(first:(second:rest)) -> SomePattern $ And $ P2.Populace2 first second rest

showMismatchUsing :: Bool -> Mismatch -> String
showMismatchUsing useMsg = \case
	LeftoverSub{..} ->
		"sub patterns could not be matched: " ++ show' (patConcat leftover.l)
	LeftoverSuper{..} ->
		"required super patterns could not be matched: " ++ show' (patConcat leftover.l)
	Mismatch{..} ->
		show' nextSub ++ " cannot prefix " ++ show' (patConcat remainingSuper.l)
	CompoundMismatch{..} ->
		showCompoundErrorsUsing show' context compound
	where
		show' :: (Show a, Messagable a) => (a -> String)
		show' = if useMsg then show else msg

instance Eq Mismatch where
	mm1@Mismatch{} == mm2@Mismatch{} = mm1.nextSub == mm2.nextSub && mm1.remainingSuper == mm2.remainingSuper
	l1@LeftoverSub{} == l2@LeftoverSub{} = l1.leftover == l2.leftover
	l1@LeftoverSuper{} == l2@LeftoverSuper{} = l1.leftover == l2.leftover
	_ == _ = False

instance Show Mismatch where
	show = showMismatchUsing False

instance Messagable Mismatch where
	msg = showMismatchUsing True

instance Ord Mismatch where
	compare mm1@Mismatch{} mm2@Mismatch{} = compare (length mm1.remainingSuper) (length mm2.remainingSuper)
	compare l1@LeftoverSub{} l2@LeftoverSub{} = compare (length l1.leftover) (length l2.leftover)
	compare l1@LeftoverSuper{} l2@LeftoverSuper{} = compare (length l1.leftover) (length l2.leftover)
	compare a b = compare (mmIndex a) (mmIndex b)
		where mmIndex = \case
			LeftoverSuper{} -> 1
			LeftoverSub{} -> 2
			Mismatch{} -> 3
			CompoundMismatch{} -> 4

instance IsError Mismatch where
	prepend newContext = \case
		cm@CompoundMismatch{..} -> cm{ context = newContext ++ context }
		mismatch -> CompoundMismatch { context = newContext, compound = P.singleton mismatch }
	m1 <!> m2 = do
		let getCompound = \case
			CompoundMismatch{..} -> Just (context, compound)
			_ -> Nothing
		compoundErrorsUsing getCompound CompoundMismatch m1 m2

instance Eq CharRange where
	CharRange a1 b1 == CharRange a2 b2 = a1 == a2 && b1 == b2

instance Show CharRange where
	show CharRange{start,end} =
		if start == end
			then escape CharClass.specials [start]
			else escape CharClass.specials [start] ++ "-" ++ escape CharClass.specials [end]

instance Messagable CharRange where
	msg = show

instance Eq Argument where
	(==) p1 p2 = p1.name == p2.name

instance Show Argument where
	show Argument{name,argType,decLoc} = showArg name argType decLoc

instance Messagable Argument where
	msg Argument{name,argType} = msgArg name argType

type GetArgs = SomePattern -> OMap String Argument

getArgsOf :: SomePattern -> OMap String Argument
getArgsOf (SomePattern p) = TPattern.getArgs p

getNonStructuralArgsOf :: SomePattern -> OMap String Argument
getNonStructuralArgsOf (SomePattern p) = TPattern.getNonStructuralArgs p

getRequiredArgsOf :: SomePattern -> OMap String Argument
getRequiredArgsOf (SomePattern p) = TPattern.getRequiredArgs p

getOrArgsUsing :: GetArgs -> Populace2 SomePattern -> OMap String (Argument, Bool)
getOrArgsUsing getArgs subpatterns = do
	let combineTypes
			:: OMap String (Argument, Bool) -> OMap String Argument -> OMap String (Argument, Bool) =
		\aArgs bArgs -> do
			let keys = Set.union (Set.fromList $ OMap.keys aArgs) (Set.fromList $ OMap.keys bArgs)
			let argInfoFor :: String -> (Argument, Bool) = \key ->
				case (OMap.lookup key aArgs, OMap.lookup key bArgs) of
					(Nothing, Just bParam) -> (bParam, True)
					(Just (aParam, _), Nothing) -> (aParam, True)
					(Just (aParam, aOptional), Just bParam) -> do
						let newParam = case (aParam.argType, bParam.argType) of
							(aType, bType) | aType == bType -> aParam
							(NativeOrType aTypes, NativeOrType bTypes) -> bParam{
								argType = NativeOrType $ P2.concat $ P2.dualton aTypes bTypes }
							(NativeOrType aTypes, bType) -> bParam{
								argType = NativeOrType $ P2.snoc aTypes bType }
							(aType, NativeOrType bTypes) -> bParam {
								argType = NativeOrType $ P2.cons aType bTypes }
							(aType, bType) -> bParam{
								argType = NativeOrType $ P2.dualton aType bType }
						(newParam, aOptional)
					(Nothing, Nothing) ->
						error $ "Attempted to retrieve arg '" ++ key ++ " from no options!"
			OMap.fromList $ map (\key -> (key, argInfoFor key)) $ Set.elems keys
	let start :: OMap String (Argument, Bool) = OMap.map (,False) $ getArgs subpatterns.head
	let argsWithoutOptionalWrappers :: OMap String (Argument, Bool) =
		foldl combineTypes start $ map getArgs subpatterns.tail.l
	let wrapOptionals :: (Argument, Bool) -> (Argument, Bool) = \(arg, optional) -> do
		let wrappedParam = if optional
			then arg{ argType = NativeOptionalType arg.argType }
			else arg
		(wrappedParam, optional)
	OMap.map wrapOptionals argsWithoutOptionalWrappers

parse :: SomePattern -> Code.Parser Match
parse (SomePattern p) = TPattern.parse p

getSubpatterns :: SomePattern -> Populace SomePattern
getSubpatterns (SomePattern p) = TPattern.getSubpatterns p

getArgs :: GetArgs
getArgs = getArgsOf

getNonStructuralArgs :: GetArgs
getNonStructuralArgs = getNonStructuralArgsOf

getRequiredArgs :: GetArgs
getRequiredArgs = getRequiredArgsOf

hasArgs :: SomePattern -> Bool
hasArgs (SomePattern p) = TPattern.hasArgs p

mustHavePrefix :: SomePattern -> Bool
mustHavePrefix (SomePattern p) = TPattern.mustHavePrefix p

mustHaveSuffix :: SomePattern -> Bool
mustHaveSuffix (SomePattern p) = TPattern.mustHaveSuffix p

canHavePrefix :: SomePattern -> Bool
canHavePrefix (SomePattern p) = TPattern.canHavePrefix p

canHaveSuffix :: SomePattern -> Bool
canHaveSuffix (SomePattern p) = TPattern.canHaveSuffix p

canMatchEmpty :: SomePattern -> Bool
canMatchEmpty (SomePattern p) = TPattern.canMatchEmpty p

startingSpaceStates :: SomePattern -> Set Code.SpaceState
startingSpaceStates (SomePattern p) = TPattern.startingSpaceStates p

isOptional :: SomePattern -> Bool
isOptional (SomePattern p) = TPattern.isOptional p

satisfies :: (TypeTest, SomePattern) -> SomePattern -> FallibleI Mismatch ()
(test, requirement) `satisfies` candidate = do
	let rejectIncompleteParses :: PC.Parses -> FallibleI Mismatch () = \parses -> do
		let errIfIncomplete = \parseResult -> case
			(parseResult.state.rest.candidate, parseResult.state.rest.requirement)
			of
			([], []) -> Falue ()
			(nextCandidate:candidateLeft, []) ->
				Error $ LeftoverSub $ P.Populace nextCandidate candidateLeft
			([], nextRequirement:requirementLeft) ->
				Error $ LeftoverSuper $ P.Populace nextRequirement requirementLeft
			(nextCandidate:_, nextRequirement:requirementLeft) ->
				Error $ Mismatch nextCandidate $ P.Populace nextRequirement requirementLeft

		let errorOfIncompletion = sequenceAny $ map errIfIncomplete parses.parses.l
		case (errorOfIncompletion, parses.bestError) of
			(Falue _, _) -> Falue ()
			(Error _, Just bestError) -> Error bestError
			(Error incomplete, Nothing) -> Error incomplete

	debugM $ "Testing pattern STRUCTURE:\n\tRequirement: " ++ msg requirement ++
		"\n\tCandidate: " ++ msg candidate
	let structuralStartState = PatternComparator.startState False test requirement candidate
	structuralParses <- structuralStartState >>> PatternComparator.comparator
	rejectIncompleteParses structuralParses

	debugM $ "Satisfied pattern STRUCTURE; testing pattern ARG TYPES:\n\tRequirement: " ++
		msg requirement ++ "\n\tCandidate: " ++ msg candidate
	let argTypesCheckStartState = PatternComparator.startState True test requirement candidate
	argTypesParses <- argTypesCheckStartState >>> PatternComparator.comparator
	rejectIncompleteParses argTypesParses
