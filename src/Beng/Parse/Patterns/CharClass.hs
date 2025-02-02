module Beng.Parse.Patterns.CharClass (
	specials,
	showClass,
	parse,
	compareFrom,
	enumerate,
	any,
	all,
	has
) where

import Prelude hiding (all, any)
import qualified Prelude

import Utils.Fallible (FallibleI(Error))
import Utils.Populace (Populace)
import qualified Utils.Populace as P

import Beng.Errors (parseError)
import Beng.Parse.Parsers ((@>), (>>>), (>\>), (>:>))
import qualified Beng.Parse.Parsers.Code as Code
import qualified Beng.Parse.Parsers.PatternComparator as PC
import qualified Beng.Parse.Parsers.PatternComparator as PatternComparator
import Beng.Types.Parse.Matches (Match)
import qualified Beng.Types.Parse.Matches as Match
import {-# SOURCE #-} Beng.Parse.Patterns ()
import Beng.Types.Parse.Patterns (CharRange(..), Mismatch(..), Pattern(..))

import Data.Char (isSpace)
import Data.List (isPrefixOf, uncons)
import qualified Data.Text.Lazy as Text

-- constants

-- This only lists characters that are special regardless of position.
specials = "{}]-"

checkUsing :: ((Char -> Bool) -> [Char] -> Bool) -> (Char -> Bool) -> Populace CharRange -> Bool -> Bool
checkUsing collate check ranges negate =
	negate /= collate check (enumerate ranges)

-- exported

enumerate :: (Populace CharRange -> [Char])
enumerate = concatMap \CharRange{..} -> [start..end]

any :: ((Char -> Bool) -> Populace CharRange -> Bool -> Bool)
any = checkUsing Prelude.any

all :: ((Char -> Bool) -> Populace CharRange -> Bool -> Bool)
all = checkUsing Prelude.all

has :: Char -> Populace CharRange -> Bool -> Bool
has c ranges negate = negate /= Prelude.any (\CharRange{..} -> start <= c && end >= c) ranges

showClass :: Populace CharRange -> Bool -> String
showClass ranges negate = do
	let contents = concatMap show ranges.l
	let contentsEscaped = if "^" `isPrefixOf` contents
		then '^':contents
		else contents
	"[" ++ (if negate then "^" else "") ++ contentsEscaped ++ "]"

parse :: Populace CharRange -> Bool -> Code.Parser Match
parse ranges negate = "parse " ++ shown @> \state ->
	case Text.uncons state.rest of
		Nothing -> Error $ parseError state $ shown ++ " was expected, but the end was reached!"
		Just (firstChar, _) ->
			if has firstChar ranges negate
				then Code.takeAs (Text.singleton firstChar) (Match.CharClass firstChar) state
				else Error $ parseError state $
					shown ++ " was expected, but '" ++ [firstChar] ++ "' was found!"
	where shown = showClass ranges negate

compareFrom :: Populace CharRange -> Bool -> PatternComparator.Parser
compareFrom ranges negate = showClass ranges negate ++ " comparator" @> \state -> do
	let self = CharClass { ranges, negate }
	case uncons state.rest.super of
		Nothing -> Error $ LeftoverSub $ P.assume state.rest.sub -- Sub must start with the pattern being parsed.
		Just (next, superLeft) -> do
			let superP = P.Populace next superLeft
			case next of
				cc@CharClass{} -> if Prelude.all (\c -> has c cc.ranges cc.negate) $ enumerate ranges
					then PC.accept [next] state
					else Error $ Mismatch self superP
				Literal "" -> state >>>
					("skip empty literal for " ++ showClass ranges negate @> PC.accept [next]) >:>
					compareFrom ranges negate >\> const ()
				Literal lit | has (Text.head lit) ranges negate -> PC.accept [next] state
				Space | any isSpace ranges negate ->
					-- TODO: optionally accept succeeding patterns with the same Space.
					PC.accept [next] state
				_ -> Error $ Mismatch self superP