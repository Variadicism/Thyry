module Beng.Parse.Parsers (
	Parse(..),
	Parses(..),
	Parser,  -- Do not export Parser internals.
	ParseRunner,
	PrefixState(..),
	SpaceState(..),
	State(..),
	prependToBestError,
	onParses,
	fileStartState,
	parse,
	takeAs1,
	takeAs,
	parseAs,
	parseAny,
	parseAll,
	parseWhile,
	(<<<),
	(>>>),
	(@>),
	(@+>),
	(>/\>),
	(>/>),
	(>:\\>),
	(>:\>),
	(>:>),
	(>-\\>),
	(>-\>),
	(>|>),
	(>^\\>),
	(>^\>),
	(>\\>),
	(>\>)
) where

import Utils.Fallible hiding (Fallible)
import Utils.Lists (ifNotNull)
import Utils.Messaging (Messagable, debugM, msg)
import Utils.Populace (Populace(..))
import qualified Utils.Populace as P

import Beng.Build.Context (Context)
import Beng.Ops ()
import Beng.Types.Parse.Parsers (Parse(..), Parses(..), Parser(..), ParseRunner, PrefixState(..), SpaceState(..), State(..))
import qualified Beng.Types.Parse.Parsers as Parser
import Beng.Errors (Error, Fallible)
import Beng.Types.Locations (FileLocation(..))

import Control.Monad (when)
import Data.Char (isAlphaNum, isSpace, toLower)
import qualified Data.Map as Map
import qualified Data.Maybe as Maybe
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

{- HERE is a cheat sheet for the meaning of all the crazy symbols in here:
   - <<< runs a Parser with the given State (equivalent to `parse`)
   - @ is for naming things:
      - @> combines a name with a ParseRunner to make a Parser.
      - @+> has a `+` because it adds onto an existing name.
   - > > is for piping the output of one parser into something else.
      - \ symbolizes a lambda; each one represents an expectation of an upcoming lambda variable
         - 1 \ passes the target parsed to the following function
         - 2 \\ passes the target and Text parsed
      - : ("and") is for running parsers sequentially and getting both results
      - - ("filter") is for filtering unwanted results (and transforming them if desired)
      - | ("or") is for running parsers from the same starting point and gathering all the results
      - ^ ("tee") is for running parsers sequentially and accepting the results of
         parsing with just the first one and parsing with both sequentially -}

-- private

type ParserChain1 t u = t -> Parser u

type ParserChain2 t u = t -> Text -> Parser u

mapParseTarget :: (t -> Text -> u) -> Parse t -> Parse u
mapParseTarget f parse = parse{ target = f parse.target parse.parsed }

mapParsesTargets :: (t -> Text -> u) -> Parses t -> Parses u
mapParsesTargets = onParses . P.map . mapParseTarget

(<!?>) :: Maybe Error -> Maybe Error -> Maybe Error
(<!?>) e1 = \case
	Nothing -> e1
	Just e2 -> case e1 of
		Nothing -> Just e2
		Just e1 -> Just $ e1 <!> e2

onMaybeBestError :: (Maybe Error -> Maybe Error) -> Parses t -> Parses t
onMaybeBestError f parses = parses{ bestError = f parses.bestError }

concatParses :: (Populace (Parses t) -> Parses t)
-- `fold1` is safe for Populaces.
concatParses = foldl1 foldParses where
	foldParses = \prev next -> prev{
		parses = prev.parses <> next.parses,
		bestError = prev.bestError <!?> next.bestError }

prependParseUsing :: (t -> u -> v) -> Parse t -> Parses u -> Parses v
prependParseUsing m t = onParses $ P.map (prependToParse t) where
	prependToParse = \t u -> u{
		parsed = t.parsed <> u.parsed,
		target = m t.target u.target }

getIndentation :: State -> String
getIndentation State{..} = do
	let numberString = show indentation
	let numberOfSpaces = indentation - length numberString + 1
	numberString ++ "|" ++ replicate numberOfSpaces ' '

debugIndented state = debugM . (getIndentation state++)

andParseFrom :: (Show t, Show u) => String -> Parses t -> ParserChain2 t u -> ParseRunner (t, u)
andParseFrom firstName firstParses secondChain = \state -> do
	-- If you write this as `let runSecond firstResult =`, HasField complains. Wat? >:(
	let runSecond = \firstParse -> do
		let second = secondChain firstParse.target firstParse.parsed
		debugIndented state $ "Pairing " ++ firstName ++ " with " ++ second.name ++ "..."
		case firstParse.state >>> second of
			Error secondError ->
				Error $ maybe secondError (<!> secondError) firstParses.bestError
			Falue secondParses ->
				-- Successes combine the first Parses's best error at the end to avoid redundancy.
				Falue $ prependParseUsing (,) firstParse secondParses

	-- Type variables prohibit type signatures here. >:(
	let mergedSubparses = P.map runSecond firstParses.parses  -- Populace (Fallible (Parses (t, u)))
	sequencedParses <- P.sequenceAny mergedSubparses  -- Fallible (Populace (Parses (t, u)))
	let pairedParses = concatParses sequencedParses  -- Parses (t, u)
	return $ onMaybeBestError (firstParses.bestError <!?>) pairedParses

andParse :: (Show t, Show u) => Parser t -> ParserChain2 t u -> ParseRunner (t, u)
andParse first secondChain = \state -> do
	firstParses <- state >>> first
	andParseFrom first.name firstParses secondChain state

orParseBeside :: String -> Fallible (Parses t) -> String -> Fallible (Parses t) -> ParseRunner t
orParseBeside firstName firstParses secondName secondParses = \state -> do
	debugIndented state $ "Alternating " ++ firstName ++ " with " ++ secondName ++ "..."
	case (firstParses, secondParses) of
		(Error firstError, Error secondError) ->
			Error $ firstError <!> secondError
		(Error firstError, Falue secondParses) ->
			Falue $ onMaybeBestError (Just firstError <!?>) secondParses
		(Falue firstParses, Error secondError) ->
			Falue $ onMaybeBestError (<!?> Just secondError) firstParses
		(Falue firstParses, Falue secondParses) ->
			Falue $ concatParses $ Populace firstParses [secondParses]

orParse :: Show t => Parser t -> Parser t -> ParseRunner t
orParse first second = \state ->
	orParseBeside first.name (state >>> first) second.name (state >>> second) state

teeParse :: Show t => Parser t -> ParserChain2 t t -> ParseRunner t
teeParse first secondChain = \state -> do
	firstParses <- state >>> first
	let teedParses = do
		secondParses <- andParseFrom first.name firstParses secondChain state
		return $ mapParsesTargets (\(_, t) _ -> t) secondParses
	orParseBeside first.name (Falue firstParses) "its tee" teedParses state

-- instances

instance Show PrefixState where
	show = \case
		Unneeded -> ""
		Needed -> "prefix-seeking"
		AvoidingFor op -> "prefix-evading for " ++ show op

instance Eq t => Eq (Parse t) where
	(==) r1 r2 = r1.target == r2.target && r1.state.rest == r2.state.rest

instance Show t => Show (Parse t) where
	show Parse{..} = show parsed ++ " as " ++ show target ++ " => " ++ show state

instance (Eq t, Ord t) => Ord (Parse t) where
	compare r1 r2 = compare r1.target r2.target <> compare r1.state.rest r2.state.rest

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

-- exported

prependToBestError :: String -> (Parses t -> Parses t)
prependToBestError prefix = onMaybeBestError (fmap $ prepend prefix)

onParses :: (Populace (Parse t) -> Populace (Parse u)) -> Parses t -> Parses u
onParses f ts = ts{ parses = f ts.parses }

fileStartState :: FilePath -> Context -> Text -> State
fileStartState file context text = State {
	context, maxPrecedence = Nothing, parent = Nothing,
	arguments = Map.empty,
	indentation = 0,
	location = FileLocation { file, line = 1, column = 1 },
	prefixState = Needed, spaceState = Space,
	rest = text }

parse :: Show t => Parser t -> ParseRunner t
parse parser = \state -> do
	when (not $ null parser.name) $ debugM $
		getIndentation state ++ "Parsing " ++ parser.name ++ " from " ++ show state ++ "..."

	let indentedResults = parser.run state{ indentation = state.indentation + 1 }
	let outdent = \parse -> parse{ Parser.state = parse.state{ indentation = parse.state.indentation - 1 }}
	let parses = fmap (onParses (P.map outdent)) indentedResults

	when (not $ null parser.name) case parses of
		Error error -> do
			debugIndented state $ "ERROR parsing " ++ parser.name ++ ":"
			debugIndented state $ show error
		Falue Parses{parses,bestError} -> do
			debugIndented state $
				(if length parses == 1 then "1 result" else show (length parses) ++ " results") ++
				" parsing " ++ parser.name ++ ":"
			sequence $ flip P.mapIndexed parses
				\i p -> debugIndented state $ show (i+1) ++ ") " ++ show p
			debugIndented state $ "Best error: " ++ maybe "[]" show bestError
	parses

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

	Parse { parsed, target, state = state{
		rest, spaceState, location } }

takeAs :: Show t => Text -> t -> ParseRunner t
takeAs parsed target = \state -> return Parses {
	parses = P.singleton $ takeAs1 parsed target state, bestError = Nothing }

parseAs :: Show t => (Text -> t -> Parser t)
parseAs text = ("" @>) . takeAs text 

parseAny :: Show t => (Populace (Parser t) -> Parser t)
parseAny = foldr1 (>|>)

{- Parse as many instances of the target as possible, "teeing off" each parse
   so that each possible parse result is listed. -}
parseAll :: Show t => Parser t -> Parser [t]
parseAll parser = "all " ++ parser.name @> \state -> state >>>
	-- A tee's tail ignoring the output of the head is usually bad, but here,
	-- we're just losing an empty list that would have been concatenated.
	parseAs "" [] >^\> \_ ->
	parser >:>
	parseAll parser >\>
	\(next, rest) -> next:rest

parseWhile :: Show t => String -> (State -> Bool) -> Parser t -> Parser [t]
parseWhile conditionDescription shouldContinue parser =
	parser.name ++ " while " ++ conditionDescription @> \state ->
		if shouldContinue state then
			state >>>
			parser >:>
			parseWhile conditionDescription shouldContinue parser >\>
			\(next, rest) -> next:rest
		else takeAs "" [] state

-- "Run": Run the parser with the given state and get the results.
(<<<) :: Show t => (Parser t -> ParseRunner t)
(<<<) = parse
infix 0 <<<

(>>>) :: Show t => (State -> Parser t -> Fallible (Parses t))
(>>>) = flip parse
infix 0 >>>

-- "Construct": make a parser form the name and how to run it.
(@>) :: String -> ParseRunner t -> Parser t
(@>) = Parser
infix 4 @>

-- "Contextualize": add contextual information to the parser's name for better debugging
(@+>) :: String -> Parser t -> Parser t
(@+>) context parser =
	"for " ++ context ++ ", " ++ parser.name @>
		parser.run
infix 0 @+>

-- "Update with Target": make an update to the state without affecting the target
(>/\>) :: Show t => Parser t -> (State -> t -> State) -> Parser t
(>/\>) parser updater = parser.name @> \state -> do
	parses <- state >>> parser
	let update parse = parse{ Parser.state = updater parse.state parse.target }
	return $ onParses (P.map update) parses
infixl 2 >/\>

-- "Update": make an update to the state without affecting the target
(>/>) :: Show t => Parser t -> (State -> State) -> Parser t
(>/>) parser updater = parser >/\> \s _ -> updater s
infixl 2 >/>

-- "And Chain 2": parse with the first, then chain to the second, and return the result targets as a pair.
(>:\\>) :: (Show t, Show u) => Parser t -> ParserChain2 t u -> Parser (t, u)
(>:\\>) first secondChain =
	first.name ++ " and ?" @>
		andParse first secondChain
infixl 3 >:\\>

-- "And Chain 2": parse with the first, then chain to the second, and return the result targets as a pair.
(>:\>) :: (Show t, Show u) => Parser t -> ParserChain1 t u -> Parser (t, u)
(>:\>) first secondChain = first >:\\> \t _ -> secondChain t
infixl 3 >:\>

-- "And": parse with the first, then the second, and return the result targets as a pair.
(>:>) :: (Show t, Show u) => Parser t -> Parser u -> Parser (t, u)
(>:>) first second = first.name ++ " and " ++ second.name @>
	andParse first \_ _ -> second
infixl 3 >:>

-- "Filter 2": filter out unwanted results by turning them to Nothing; transform successes if desired
(>-\\>) :: Show t => Parser t -> (t -> Text -> Fallible u) -> Parser u
(>-\\>) parser transform = parser.name ++ " filtered" @> \state -> do
	parses <- parser <<< state
	let applyFilter parse = do
		newTarget <- transform parse.target parse.parsed
		return $ parse{ target = newTarget }
	filteredParses <- P.sequenceAny $ P.map applyFilter parses.parses
	return parses{ parses = filteredParses }
	
infixl 2 >-\\>

-- "Filter 1": filter out unwanted results by turning them to Nothing; transform successes if desired
(>-\>) :: Show t => Parser t -> (t -> Fallible u) -> Parser u
(>-\>) parser transform = parser >-\\> \t _ -> transform t
infixl 2 >-\>

-- "Or": combine the results of two parsers, i.e., parse using either parser
(>|>) :: Show t => Parser t -> Parser t -> Parser t
(>|>) parser1 parser2 = 
	parser1.name ++ " or " ++ parser2.name @>
		orParse parser1 parser2
infixl 1 >|>

-- "Tee 2": use the first parser, then chain to the next, BUT accept results from the first alone AND the chain.
(>^\\>) :: Show t => Parser t -> ParserChain2 t t -> Parser t
(>^\\>) start continueChain = start.name ++ " teed to ?" @>
	teeParse start continueChain
infixl 2 >^\\>

-- "Tee 1"
(>^\>) :: Show t => Parser t -> ParserChain1 t t -> Parser t
(>^\>) start continueChain = start >^\\> \t _ -> continueChain t
infixl 2 >^\>

--- There is no Tee without chaining because that could silently discard previous results!

-- "Fmap 2": map the given function to each Parse using its target and parsed Text
-- This is equivalent to (>\>) except that it passes the parsed Text in addition to the target
(>\\>) :: Parser t -> (t -> Text -> u) -> Parser u
(>\\>) parser f = parser{ run = fmap (mapParsesTargets f) . parser.run }
infixl 2 >\\>

-- "Fmap 1": map the given function to each Parse using its target
-- This is equivalent to (>\\>) excep that it does not pass the parsed Text
(>\>) :: Parser t -> (t -> u) -> Parser u
(>\>) parser targetMapper = parser >\\> \target _ -> targetMapper target
infixl 2 >\>