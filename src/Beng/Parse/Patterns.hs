module Beng.Parse.Patterns (
	specials,
	parse,
	getSubpatterns,
	getArgs,
	getRequiredArgs,
	hasArgs,
	mustHavePrefix,
	mustHaveSuffix,
	canHavePrefix,
	canHaveSuffix,
	isOptional,
	satisfies,
	module Beng.Types.Parse.Patterns
) where

import Utils.Fallible
import Utils.Lists (takeUntilIncl, wrap)
import qualified Utils.Maps.Ordered as OMap
import Utils.Messaging (Messagable, msg)
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Populace.Populace2 (Populace2)
import qualified Utils.Populace.Populace2 as P2
import Utils.Strings (escape, parenthesize)

import Beng.Build.Context.Builders (patConcat)
import Beng.Errors (compoundErrorsUsing, showCompoundErrorsUsing)
import qualified Beng.Parse.Patterns.And as And
import Beng.Parse.Patterns.Arg (msgArg, showArg)
import qualified Beng.Parse.Patterns.Arg as Argument
import qualified Beng.Parse.Patterns.CharClass as CharClass
import qualified Beng.Parse.Patterns.Delimited as Delimited
import qualified Beng.Parse.Patterns.Literal as Literal
import qualified Beng.Parse.Patterns.NamedText as NamedText
import qualified Beng.Parse.Patterns.Or as Or
import qualified Beng.Parse.Patterns.Space as Space
import Beng.Parse.Matches (Match)
import Beng.Parse.Parsers ((>>>))
import qualified Beng.Parse.Parsers.Code as Code
import {-# SOURCE #-} qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Patterns
import Beng.Types.SatisfactionTest (SatisfactionTest)
import Beng.Types.Things (Thing(..))

import Data.List (intercalate)
import Data.Map.Ordered ((<>|), OMap)
import qualified Data.Map.Ordered as OMap
import qualified Data.Set as Set
import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text

-- constants

-- ^ and $ are not applicable in Literal patterns.
specials = ".{}[] "

-- private

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

-- instances

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
			CompoundMismatch{} -> 4 -- impossible

instance IsError Mismatch where
	prepend newContext = \case
		cm@CompoundMismatch{..} -> cm{ context = newContext ++ context }
		mismatch -> CompoundMismatch { context = newContext, compound = P.singleton mismatch }
	m1 <!> m2 = do
		let getCompound = \case
			CompoundMismatch{..} -> Just (context, compound)
			_ -> Nothing
		compoundErrorsUsing getCompound CompoundMismatch m1 m2

deriving instance Eq CharRange

instance Show CharRange where
	show CharRange{start,end} =
		if start == end
			then escape CharClass.specials [start]
			else escape CharClass.specials [start] ++ "-" ++ escape CharClass.specials [end]

instance Messagable CharRange where
	msg = show

instance Eq Parameter where
	(==) p1 p2 = p1.name == p2.name

instance Show Parameter where
	show Parameter{name,paramType,decLoc} = showArg name paramType decLoc

instance Messagable Parameter where
	msg Parameter{name,paramType} = msgArg name paramType

deriving instance Eq Pattern

instance Show Pattern where
	show p = '\\' : showPatternWith False p

instance Messagable Pattern where
	-- In the future, I might show simplified versions of some patterns or a simple subset of the pattern here.
	msg p = '\\' : case p of
		Argument{name,argType} -> msgArg name argType
		p -> showPatternWith True p

-- private

showPatternWith :: Bool -> Pattern -> String
showPatternWith useMsg = \case
	Space -> " "
	Literal literal -> unpack literal
	CharClass{ranges,negate} -> CharClass.showClass ranges negate
	NamedText{name,subpattern} -> wrap "\"" name ++ parenthesize (showPatternWith useMsg subpattern)
	And subpatterns -> concatMap (showPatternWith useMsg) subpatterns
	Or subpatterns -> parenthesize $ intercalate "|" $ map (showPatternWith useMsg) subpatterns.l
	Delimited{..} ->
		-- TODO: determine if parentheses are necessary based on precedence.
		parenthesize (showPatternWith useMsg delimitend) ++ "{" ++ showPatternWith useMsg delimiter ++ "}"
	Argument{name,argType,decLoc} -> if useMsg
		then msgArg name argType
		else showArg name argType decLoc

getOrArgs :: Populace2 Pattern -> OMap String (Parameter, Bool)
getOrArgs subpatterns = do
	let combineTypes
			:: OMap String (Parameter, Bool) -> OMap String Parameter -> OMap String (Parameter, Bool) =
		\aArgs bArgs -> do
			let keys = Set.union (Set.fromList $ OMap.keys aArgs) (Set.fromList $ OMap.keys bArgs)
			let paramInfoFor :: String -> (Parameter, Bool) = \key ->
				case (OMap.lookup key aArgs, OMap.lookup key bArgs) of
					(Nothing, Just bParam) -> (bParam, True)
					(Just (aParam, _), Nothing) -> (aParam, True)
					(Just (aParam, aOptional), Just bParam) -> do
						let newParam = case (aParam.paramType, bParam.paramType) of
							(aType, bType) | aType == bType -> aParam
							(NativeOrType aTypes, NativeOrType bTypes) -> bParam{
								paramType = NativeOrType $ P2.concat $ P2.dualton aTypes bTypes }
							(NativeOrType aTypes, bType) -> bParam{
								paramType = NativeOrType $ P2.snoc aTypes bType }
							(aType, NativeOrType bTypes) -> bParam {
								paramType = NativeOrType $ P2.cons aType bTypes }
							(aType, bType) -> bParam{
								paramType = NativeOrType $ P2.dualton aType bType }
						(newParam, aOptional)
					(Nothing, Nothing) ->
						-- This is impossible because this is mapped over keys from aArgs and bArgs, so
						-- at least one of them must have it.
						error $ "Attempted to retrieve arg '" ++ key ++ " from no options!"
			OMap.fromList $ map (\key -> (key, paramInfoFor key)) $ Set.elems keys
	let start :: OMap String (Parameter, Bool) = OMap.map (,False) $ getArgs subpatterns.head
	let argsWithoutOptionalWrappers :: OMap String (Parameter, Bool) =
		foldl combineTypes start $ map getArgs subpatterns.tail.l
	let wrapOptionals :: (Parameter, Bool) -> (Parameter, Bool) = \(param, optional) -> do
		let wrappedParam = if optional
			then param{ paramType = NativeOptionalType param.paramType }
			else param
		(wrappedParam, optional)
	OMap.map wrapOptionals argsWithoutOptionalWrappers

-- exports

parse :: Pattern -> Code.Parser Match
parse = \case
	Space -> Space.parse
	Literal literal -> Literal.parse literal
	CharClass{ranges,negate} -> CharClass.parse ranges negate
	NamedText{name,subpattern,decLoc} -> NamedText.parse name subpattern decLoc
	And subpatterns -> And.parse subpatterns
	Or subpatterns -> Or.parse subpatterns
	Delimited{delimiter,delimitend} -> Delimited.parse delimiter delimitend
	Argument{name,argType,decLoc} -> Argument.parse name argType decLoc

getSubpatterns :: Pattern -> Populace Pattern
getSubpatterns = \case
	NamedText{subpattern} -> P.singleton subpattern
	And subpatterns -> subpatterns.p1
	Or subpatterns -> subpatterns.p1
	Delimited{..} -> P.Populace delimitend [delimiter]
	pattern -> P.singleton pattern

getArgs :: Pattern -> OMap String Parameter
getArgs = \case
	NamedText{decLoc,name} -> OMap.singleton (name,
		Parameter { decLoc, name, paramType = NativeStringType })
	And subpatterns -> OMap.concat $ map getArgs subpatterns.l
	Or subpatterns -> OMap.map fst $ getOrArgs subpatterns
	Delimited delimiter delimitend ->
		(wrapTypes NativeSomeType $ getArgs delimiter) <>|
		(wrapTypes NativeListType $ getArgs delimitend)
	Argument{decLoc,name,argType} -> OMap.singleton (name,
		Parameter { decLoc, name, paramType = argType })
	_ -> OMap.empty
	where
		wrapType :: (Thing -> Thing) -> Parameter -> Parameter
		wrapType wrapper p = p{ paramType = wrapper p.paramType }
		wrapTypes :: (Thing -> Thing) -> OMap String Parameter -> OMap String Parameter
		wrapTypes wrapper = OMap.map (wrapType wrapper)

getRequiredArgs :: Pattern -> OMap String Parameter
getRequiredArgs = \case
	Or subpatterns -> OMap.map fst $ OMap.filter (\_ (_, optional) -> not optional) $ getOrArgs subpatterns
	pattern -> getArgs pattern

hasArgs :: Pattern -> Bool
hasArgs = not . null . getArgs

mustHavePrefix :: (Pattern -> Bool)
mustHavePrefix = \case
	Space -> False
	Literal literal -> not $ Text.null literal
	CharClass{} -> True
	NamedText{subpattern} -> not $ NamedText.canBeEmpty subpattern
	And subpatterns ->
		any mustHavePrefix $ takeUntilIncl hasArgs subpatterns.l
	Or subpatterns -> all mustHavePrefix subpatterns
	Delimited _ delimitend -> mustHavePrefix delimitend
	Argument{} -> False

mustHaveSuffix :: (Pattern -> Bool)
mustHaveSuffix = \case
	And subpatterns ->
		any mustHaveSuffix $ takeUntilIncl hasArgs $ reverse subpatterns.l
	Or subpatterns -> all mustHaveSuffix subpatterns.l
	Delimited _ delimitend -> mustHaveSuffix delimitend
	pattern -> mustHavePrefix pattern

canHavePrefix :: (Pattern -> Bool)
canHavePrefix = \case
	Space -> True
	NamedText{} -> True
	And subpatterns ->
		any canHavePrefix $ takeUntilIncl hasArgs subpatterns.l
	Or subpatterns -> any canHavePrefix subpatterns
	Delimited delimiter delimitend -> any canHavePrefix [delimiter, delimitend]
	pattern -> mustHavePrefix pattern

canHaveSuffix :: (Pattern -> Bool)
canHaveSuffix = \case
	And subpatterns ->
		any canHaveSuffix $ takeUntilIncl hasArgs $ reverse subpatterns.l
	Or subpatterns -> any canHaveSuffix subpatterns
	Delimited delimiter delimitend -> any canHaveSuffix [delimiter, delimitend]
	pattern -> canHavePrefix pattern

isOptional :: (Pattern -> Bool)
isOptional = \case
	Literal literal -> Text.null literal
	NamedText{subpattern} -> isOptional subpattern
	And subpatterns -> do
		{- Spaces are non-optional _unless_ everything either before or after it is optional.
		   Since everything else must be optional for this to pass anyway, we don't need any complex logic
		   checking that everything before or after each Space is optional; if everything besides Spaces
		   are optional, then everything before AND after must be optional. -}
		let isSpace = \case -- Seriously, is there a better way to check this?
			Space -> True
			_ -> False
		all isOptional $ filter (not . isSpace) subpatterns.l
	Or subpatterns -> any isOptional subpatterns
	Delimited _ delimitend -> isOptional delimitend
	_ -> False

satisfies :: (SatisfactionTest, Pattern) -> Pattern -> FallibleI Mismatch ()
(test, super) `satisfies` sub = do
	let startState = PatternComparator.startState test super sub
	parses <- startState >>> PatternComparator.comparator
	-- Writing this as `let isComplete parse =` causes errors with HasField. >:(
	let isComplete = \parse -> case (parse.state.rest.sub, parse.state.rest.super) of
		([], []) -> Falue ()
		(nextSub:subLeft, []) -> Error $ LeftoverSub $ P.Populace nextSub subLeft
		([], nextSuper:superLeft) -> Error $ LeftoverSuper $ P.Populace nextSuper superLeft
		(nextSub:_, nextSuper:superLeft) -> Error $ Mismatch nextSub $ P.Populace nextSuper superLeft
	-- `foldl1` is safe because it's used on a Populace.
	let errorOfIncompletion = sequenceAny $ map isComplete parses.parses.l
	case (errorOfIncompletion, parses.bestError) of
		(Falue _, _) -> Falue ()
		(Error _, Just bestError) -> Error bestError
		(Error incomplete, Nothing) -> Error incomplete