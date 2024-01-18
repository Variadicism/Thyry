module Beng.Parse.Parsers (
	Parser,  -- Do not export Parser internals.
	ParseRunner,
	PrefixState(..),
	Result(..),
	SpaceState(..),
	State(..),
	fileStartState,
	parse,
	takeAs1,
	takeAs,
	parseAs,
	takeNone,
	parseNone,
	parseAny,
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

import Utils.Lists (ifNotNull)
import Utils.Messaging (Messagable, debug, msg)

import Beng.Build.Context (Context)
import Beng.Ops ()
import Beng.Parse.Types.Parsers (Parser(..), ParseRunner, PrefixState(..), Result(..), SpaceState(..), State(..))

import Data.Char (isAlphaNum, isSpace, toLower)
import Data.List (singleton)
import qualified Data.Map as Map
import Data.Maybe (catMaybes)
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

getIndentation :: State -> String
getIndentation State{..} = do
	let numberString = show indentation
	let numberOfSpaces = indentation - length numberString + 1
	numberString ++ "|" ++ replicate numberOfSpaces ' '

andParse :: (Show t, Show u) => Parser t -> ParserChain2 t u -> ParseRunner (t, u)
andParse first secondChain = do
	let runSecond firstResult = do
		let second = secondChain firstResult.target firstResult.parsed
		let secondResults =
			debug (getIndentation firstResult.state ++
					"Pairing " ++ first.name ++ " with " ++ second.name ++ "...")
				(second <<< firstResult.state)
		let combineResults secondResult = secondResult{
			parsed = Text.concat [parsed firstResult, parsed secondResult],
			target = (firstResult.target, secondResult.target) }
		map combineResults secondResults
	concatMap runSecond . first.run

orParse :: ParseRunner t -> ParseRunner t -> ParseRunner t
orParse first second = \state -> first state ++ second state

teeParse :: Show t => Parser t -> ParserChain2 t t -> ParseRunner t
teeParse start continueChain = do
	let startAndContinue startResult = do
		let continue = continueChain startResult.target startResult.parsed
		let continueResults =
			debug (getIndentation startResult.state ++
					"Teeing " ++ start.name ++ " off to " ++ continue.name ++ "...")
				(continue <<< startResult.state)
		let prependStartResult continuedResult = continuedResult{
			parsed = Text.concat [startResult.parsed, continuedResult.parsed] }
		startResult : map prependStartResult continueResults
	concatMap startAndContinue . start.run

-- instances

instance Show PrefixState where
	show = \case
		Unneeded -> ""
		Needed -> "prefix-seeking"
		AvoidingFor op -> "prefix-evading for " ++ show op

instance Eq t => Eq (Result t) where
	(==) :: Result t -> Result t -> Bool
	(==) r1 r2 = r1.target == r2.target && r1.state.rest == r2.state.rest

instance Show t => Show (Result t) where
	show Result{..} = show parsed ++ " as " ++ show target ++ " => " ++ show state

instance (Eq t, Ord t) => Ord (Result t) where
	compare r1 r2 = compare r1.target r2.target <> compare r1.state.rest r2.state.rest

instance Messagable State where
	msg State{..} =
		"post-" ++ map toLower (show spaceState) ++ " " ++
		ifNotNull (++" ") (show prefixState) ++
		msg rest ++
		" with " ++ show (map (\(name, capture) -> name ++ " := " ++ show capture) $ Map.assocs arguments)

instance Show State where
	show state@State{..} = msg state ++
		" at depth " ++ show indentation ++
		maybe "" ((" within "++) . show) parent ++
		maybe "" ((" with precedence < "++) . show) maxPrecedence ++
		" using " ++ show context

-- exported

fileStartState :: Context -> Text -> State
fileStartState context text = State {
	context, maxPrecedence = Nothing, parent = Nothing,
	arguments = Map.empty,
	indentation = 0,
	prefixState = Needed, spaceState = Space,
	rest = text }

parse :: Show t => Parser t -> ParseRunner t
parse parser state = debugStart $ debugResults $ (map outdent . parser.run . indent) state
	where
		-- outdent :: Result t -> Result t
		outdent result = result{ state = result.state{ indentation = result.state.indentation - 1 }}

		indent :: State -> State
		indent state = state{ indentation = state.indentation + 1 }

		debugStart :: Show a => (a -> a)
		debugStart = if null parser.name then id else
			debug (getIndentation state ++
				"Attempting to parse " ++ parser.name ++ " from " ++ show state ++ "...")

		debugResults :: Show a => [a] -> [a]
		debugResults results =
			if null parser.name then results else
				debug (getIndentation state ++
					(if null results then "No results"
						else if length results == 1 then "1 result"
						else show (length results) ++ " results") ++
					" parsing " ++ parser.name ++
					(ifNotNull (":"++) $ concat $
						 (map ((("\n"++(getIndentation state))++) . show) results))) results

takeAs1 :: Show t => Text -> t -> State -> Result t
takeAs1 parsed target state = do
	let rest = Text.drop (Text.length parsed) state.rest
	let spaceState = if Text.null parsed
		then state.spaceState
		else case Text.last parsed of
			c | isSpace c -> Space
			c | isAlphaNum c -> Word
			_ -> Punctuation
	-- TODO: When location metadata is added, this will increment those counters.
	Result { state = state{ rest, spaceState }, parsed, target}

takeAs :: Show t => Text -> t -> ParseRunner t
takeAs parsed target = singleton . takeAs1 parsed target

parseAs :: Show t => (Text -> t -> Parser t)
parseAs text = ("" @>) . takeAs text

takeNone :: ParseRunner t
takeNone = const []

parseNone :: Parser t
parseNone = "" @> takeNone

parseAny :: Show t => ([Parser t] -> Parser t)
parseAny = \case
	[] -> "parsing any of []" @> takeNone
	[only] -> only
	(first:rest) -> foldl (>|>) first rest

{- Parse as many instances of the target as possible, "teeing off" each parse
   so that each possible parse result is listed. -}
parseWhile :: Show t => Parser t -> Parser [t]
parseWhile parser = parser.name ++ " indefinitely" @+>
	-- A tee's tail ignoring the output of the head is usually bad, but here,
	-- we're just losing an empty list that would have been concatenated.
	parseAs "" [] >^\> \_ ->
	parser >:>
	parseWhile parser >\>
	\(next, rest) -> next:rest
		

-- "Run": Run the parser with the given state and get the results.
(<<<) :: Show t => (Parser t -> ParseRunner t)
(<<<) = parse
infix 0 <<<

(>>>) :: Show t => (State -> Parser t -> [Result t])
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
	map update (state >>> parser)
	where
		update result = result{ state = updater result.state result.target }
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
(>-\\>) :: Parser t -> (t -> Text -> Maybe u) -> Parser u
(>-\\>) parser transform = parser.name ++ " filtered" @>
	catMaybes . map extractMaybe . (parser >\\> transform).run
	where
		-- Damn you and your type-variable-dysfunction nonsense.
		-- extractMaybe :: Result (Maybe a) -> Maybe (Result a)
		extractMaybe result = case result.target of
			Nothing -> Nothing
			Just target -> Just result{ target }
infixl 2 >-\\>

-- "Filter 1": filter out unwanted results by turning them to Nothing; transform successes if desired
(>-\>) :: Parser t -> (t -> Maybe u) -> Parser u
(>-\>) parser transform = parser >-\\> \t _ -> transform t
infixl 2 >-\>

-- "Or": combine the results of two parsers, i.e., parse using either parser
(>|>) :: Parser t -> Parser t -> Parser t
(>|>) parser1 parser2 = 
	parser1.name ++ " or " ++ parser2.name @>
		orParse parser1.run parser2.run
infixl 1 >|>

-- "Tee 2": use the first parser, then chain to the next, BUT accept results from the first alone AND the chain.
(>^\\>) :: Show t => Parser t -> ParserChain2 t t -> Parser t
(>^\\>) start continueChain =
	start.name ++ " teed to ?" @>
		teeParse start continueChain
infixl 2 >^\\>

-- "Tee 1"
(>^\>) :: Show t => Parser t -> ParserChain1 t t -> Parser t
(>^\>) start continueTee = start >^\\> \t _ -> continueTee t
infixl 2 >^\>

--- There is no Tee without chaining because that could silently discard previous results!

-- "Fmap 2": map the given function to each Result using its target and parsed Text
-- This is equivalent to (>\>) except that it passes the parsed Text in addition to the target
(>\\>) :: Parser t -> (t -> Text -> u) -> Parser u
(>\\>) parser targetMapper = parser{
	run = do
		let mapResult = \result -> result{
			target = targetMapper result.target result.parsed }
		map mapResult . parser.run }
infixl 2 >\\>

-- "Fmap 1": map the given function to each Result using its target
-- This is equivalent to (>\\>) excep that it does not pass the parsed Text
(>\>) :: Parser t -> (t -> u) -> Parser u
(>\>) parser targetMapper = parser >\\> \target _ -> targetMapper target
infixl 2 >\>