module Beng.Parse.Patterns.CharClass (
	specials,
	showClass,
	parse,
	enumerate,
	any,
	all,
	has
) where

import Prelude hiding (all, any)
import qualified Prelude

import Utils.Fallible (FallibleI(Error))
import Utils.Messaging (Messagable(..))
import Utils.Populace (Populace)
import qualified Utils.Populace as P

import Beng.Errors (parseError)
import {-# SOURCE #-} Beng.Parse.Matches ()
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>:>))
import qualified Beng.Parse.Parsers.Code as Code
import Beng.Parse.Parsers.PatternComparator (accept, compareAsRequirementDefault)
import qualified Beng.Types.Parse.Matches as Match
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern)
import {-# SOURCE #-} Beng.Parse.Patterns.Literal ()
import {-# SOURCE #-} Beng.Parse.Patterns.Space ()
import Beng.Types.Parse.Parsers.PatternComparator (
	Comparator,
	Comparison(..),
	ComparatorState(..))
import qualified Beng.Types.Parse.Patterns as Pattern
import Beng.Types.Parse.Patterns (
	CharClass(..),
	CharRange(..),
	Literal(..),
	Mismatch(..),
	Pattern,
	SomePattern(..),
	Space(..))

import Data.Char (isAlphaNum, isSpace)
import Data.List (isPrefixOf, uncons)
import qualified Data.Set as Set
import qualified Data.Text.Lazy as Text

specials = "{}]-"

checkUsing :: ((Char -> Bool) -> [Char] -> Bool) -> (Char -> Bool) -> Populace CharRange -> Bool -> Bool
checkUsing collate check ranges negate =
	negate /= collate check (enumerate ranges)

enumerate :: Populace CharRange -> [Char]
enumerate = concatMap \CharRange{..} -> [start..end]

any :: (Char -> Bool) -> Populace CharRange -> Bool -> Bool
any = checkUsing Prelude.any

all :: (Char -> Bool) -> Populace CharRange -> Bool -> Bool
all = checkUsing Prelude.all

has :: Char -> Populace CharRange -> Bool -> Bool
has c ranges negate = negate /= Prelude.any (\CharRange{..} -> start <= c && end >= c) ranges

showClass :: Populace CharRange -> Bool -> String
showClass ranges negate = do
	let contents = concatMap show ranges.l
	let contentsEscaped = if "^" `isPrefixOf` contents then '^' : contents else contents
	"[" ++ (if negate then "^" else "") ++ contentsEscaped ++ "]"

parseCharClass :: CharClass -> Code.Parser Match.CharClass
parseCharClass CharClass{..} = do
	let shown = showClass ranges negate
	"parse " ++ shown @> \state ->
		case Text.uncons state.rest of
			Nothing -> Error $ parseError state $ shown ++ " was expected, but the end was reached!"
			Just (firstChar, _) -> if has firstChar ranges negate then
				Code.takeAs (Text.singleton firstChar) (Match.CharClass firstChar) state
			else
				Error $ parseError state $
					shown ++ " was expected, but '" ++ [firstChar] ++ "' was found!"

compareAsCandidateCharClass :: CharClass -> Comparator
compareAsCandidateCharClass self@CharClass{..} = showClass ranges negate ++ " comparator" @> \state -> do
	case uncons state.rest.requirement of
		Nothing -> Error $ LeftoverCandidate $ P.assume state.rest.candidate
		Just (next, requirementLeft) -> do
			let requirementP = P.Populace next requirementLeft
			let compareAgainstSpace = case asPattern next :: Maybe Space of
				Just Space -> if any isSpace ranges negate
					then accept [next] state
					else Error $ Mismatch (SomePattern self) requirementP
				Nothing -> Error $ Mismatch (SomePattern self) requirementP
			case asPattern next :: Maybe CharClass of
				Just cc -> if Prelude.all (\c -> has c cc.ranges cc.negate) $ enumerate ranges then
					accept [next] state
				else
					Error $ Mismatch (SomePattern self) requirementP
				Nothing -> case asPattern next :: Maybe Literal of
					Just (Literal literal) -> if Text.null literal then
						state >>> ("skip empty literal for " ++ showClass ranges negate @> accept [next]) >:>
							compareAsCandidateCharClass self >\> const ()
					else if has (Text.head literal) ranges negate then
						accept [next] state
					else
						compareAgainstSpace
					Nothing -> compareAgainstSpace

instance Eq CharClass where
	a == b = a.ranges == b.ranges && a.negate == b.negate

instance Show CharClass where
	show CharClass{..} = showClass ranges negate

instance Messagable CharClass where
	msg = show

instance Pattern Match.CharClass CharClass where
	parse = parseCharClass
	compareAsCandidate = compareAsCandidateCharClass
	compareAsRequirement self = compareAsRequirementDefault (SomePattern self)
	mustHavePrefix _ = True
	mustHaveSuffix _ = True
	canHavePrefix _ = True
	canHaveSuffix _ = True
	canMatchEmpty _ = False
	startingSpaceStates CharClass{..} = do
		let values = enumerate ranges
		Set.fromList $
			Prelude.filter (\state -> Prelude.any (hasState state) values) [Code.Space, Code.Word, Code.Punctuation]
	isOptional _ = False

parse :: CharClass -> Code.Parser Match.CharClass
parse = parseCharClass

hasState :: Code.SpaceState -> Char -> Bool
hasState state c = case state of
	Code.Space -> isSpace c
	Code.Word -> isAlphaNum c
	Code.Punctuation -> not (isSpace c || isAlphaNum c)
