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
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>:>))
import qualified Beng.Parse.Parsers.Code as Code
import qualified Beng.Parse.Parsers.PatternComparator as PC
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import {-# SOURCE #-} Beng.Parse.Patterns (asPattern)
import qualified Beng.Types.Parse.Patterns as TPattern
import Beng.Types.Parse.Patterns (
	CharClass(..),
	CharRange(..),
	Comparison(..),
	ComparatorState(..),
	Literal(..),
	Mismatch(..),
	SomePattern(..),
	Space(..))

import Data.Char (isSpace)
import Data.List (isPrefixOf, uncons)
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

parseCharClass :: CharClass -> Code.Parser Match
parseCharClass CharClass{..} = "parse " ++ shown @> \state ->
	case Text.uncons state.rest of
		Nothing -> Error $ parseError state $ shown ++ " was expected, but the end was reached!"
		Just (firstChar, _) ->
			if has firstChar ranges negate
				then Code.takeAs (Text.singleton firstChar) (Match.CharClass firstChar) state
				else Error $ parseError state $
					shown ++ " was expected, but '" ++ [firstChar] ++ "' was found!"
	where shown = showClass ranges negate

compareFromCharClass :: CharClass -> PatternComparator.Parser
compareFromCharClass self@CharClass{..} = showClass ranges negate ++ " comparator" @> \state -> do
	case uncons state.rest.super of
		Nothing -> Error $ LeftoverSub $ P.assume state.rest.sub
		Just (next, superLeft) -> do
			let superP = P.Populace next superLeft
			case asPattern next :: Maybe CharClass of
				Just cc ->
					if Prelude.all (\c -> has c cc.ranges cc.negate) $ enumerate ranges
						then PC.accept [next] state
						else Error $ Mismatch (SomePattern self) superP
				Nothing -> case asPattern next :: Maybe Literal of
					Just (Literal literal) | not (Text.null literal) && has (Text.head literal) ranges negate ->
						PC.accept [next] state
					Just (Literal literal) | Text.null literal ->
						state >>> ("skip empty literal for " ++ showClass ranges negate @> PC.accept [next]) >:>
							compareFromCharClass self >\> const ()
					_ | maybe False (const True) (asPattern next :: Maybe Space) && any isSpace ranges negate ->
						PC.accept [next] state
					_ -> Error $ Mismatch (SomePattern self) superP

instance Eq CharClass where
	a == b = a.ranges == b.ranges && a.negate == b.negate

instance Show CharClass where
	show CharClass{..} = showClass ranges negate

instance Messagable CharClass where
	msg = show

instance TPattern.Pattern CharClass where
	parse = parseCharClass
	compareFrom = compareFromCharClass
	showPatternWith _ CharClass{..} = showClass ranges negate
	mustHavePrefix _ = True
	mustHaveSuffix _ = True
	canHavePrefix _ = True
	canHaveSuffix _ = True
	isOptional _ = False

parse :: CharClass -> Code.Parser Match
parse = parseCharClass
