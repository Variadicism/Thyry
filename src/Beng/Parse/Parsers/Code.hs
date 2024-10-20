module Beng.Parse.Parsers.Code (
	Parse,
	Parses,
	Parser,
	ParseRunner,
	PrefixState(..),
	SpaceState(..),
	State(..),
	fileStartState,
	takeAs1,
	takeAs,
	parseAll,
	parseWhile,
	module Beng.Parse.Parsers
) where

import Utils.Lists (ifNotNull)
import Utils.Messaging (Messagable, msg)

import Beng.Build.Context (Context)
import Beng.Ops ()
import Beng.Parse.Parsers hiding (Parse, Parses, ParseRunner, Parser, State)
import qualified Beng.Parse.Parsers as Parser
import Beng.Types.Parse.Parsers.Code (Parse, Parses, Parser, ParseRunner, PrefixState(..), SpaceState(..), State(..))
import Beng.Types.Locations (FileLocation(..))

import Data.Char (isAlphaNum, isSpace, toLower)
import qualified Data.Map as Map
import qualified Data.Maybe as Maybe
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

-- instances

instance Show PrefixState where
	show = \case
		Unneeded -> ""
		Needed -> "prefix-seeking"
		AvoidingFor op -> "prefix-evading for " ++ show op

instance Messagable State where
	msg State{..} =
		"post-" ++ map toLower (show spaceState) ++ " " ++
		ifNotNull (++" ") (show prefixState) ++
		show rest ++
		" with " ++ show (map (\(name, capture) -> name ++ " := " ++ show capture) $ Map.assocs arguments)

instance Show State where
	show state@State{..} = msg state ++
		" at depth " ++ show indentation ++
		maybe "" ((" within "++) . show) parent ++
		maybe "" ((" with precedence < "++) . show) maxPrecedence ++
		" using " ++ show context

instance Parser.State Text State where
	rest state = state.rest
	indentation state = state.indentation
	indent s = s{ indentation = s.indentation + 1 }
	outdent s = s{ indentation = s.indentation - 1 }

-- exported

fileStartState :: FilePath -> Context -> Text -> State
fileStartState file context text = State {
	context, maxPrecedence = Nothing, parent = Nothing,
	arguments = Map.empty,
	indentation = 0,
	location = FileLocation { file, line = 1, column = 1 },
	prefixState = Needed, spaceState = Space,
	rest = text }

takeAs1 :: Show t => Text -> t -> State -> Parse t
takeAs1 parsed target state = do
	let maybeRest = Text.stripPrefix parsed state.rest
	let rest = flip Maybe.fromMaybe maybeRest $ error $
		"A Parser requested that " ++ show parsed ++ " be parsed from " ++ show state.rest ++
		", but the former is not a prefix of the latter!"
	let spaceState = if Text.null parsed
		then state.spaceState
		else case Text.last parsed of
			c | isSpace c -> Space
			c | isAlphaNum c -> Word
			_ -> Punctuation

	let ol = state.location
	-- `lines` discards trailing empty lines, including "", but `split` does not.
	let linesParsed = Text.split (=='\n') parsed
	let location = ol{
		line = ol.line + length linesParsed - 1,  -- The first Text is from the current line.
		-- `last` is safe because `split` guarantees a non-empty result.
		column = fromIntegral (Text.length $ last linesParsed) +
			if length linesParsed == 1 then ol.column else 1 {- Column numbers start at 1. -} }

	-- Since Parse from *.Code is a type alias, it can't be constructed. :(
	Parser.Parse { parsed, target, state = state{
		rest, spaceState, location } }

takeAs :: Show t =>	Text -> t -> ParseRunner t
takeAs = Parser.takeAsUsing takeAs1

takeAsNull :: Show t => t -> ParseRunner t
takeAsNull = takeAs ""

parseAll :: Show t => Parser t -> Parser [t]
parseAll = Parser.parseAllUsing takeAsNull

parseWhile :: Show t => String -> (State -> Bool) -> Parser t -> Parser [t]
parseWhile = Parser.parseWhileUsing takeAsNull
