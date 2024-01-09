module Beng.Parse.Parsers (
	Parser,  -- Do not export Parser internals.
	ParseRunner,
	Result(..),
	SpaceState(..),
	State(..),
	parse,
	takeAs1,
	takeAs,
	parseAs,
	takeNone,
	parseNone,
	parseWhile,
	(<<<),
	(@>),
	(@+>),
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

import Utils.Messaging (Messagable, debug, msg, msgShow)

import Beng.Build.Context ()
import Beng.Parse.Types.Parsers (Parser(..), ParseRunner, Result(..), SpaceState(..), State(..))

import Data.Char (isAlphaNum, isSpace, toLower)
import Data.List (singleton)
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

andParse :: ParseRunner t -> ParserChain2 t u -> ParseRunner (t, u)
andParse first secondChain = do
	let runSecond firstResult = do
		let second = secondChain firstResult.target firstResult.parsed
		let combineResults secondResult = secondResult{
			parsed = Text.concat [parsed firstResult, parsed secondResult],
			target = (firstResult.target, secondResult.target) }
		let secondResults = second <<< firstResult.state
		map combineResults secondResults
	concatMap runSecond . first

orParse :: ParseRunner t -> ParseRunner t -> ParseRunner t
orParse first second = \state -> first state ++ second state

teeParse :: ParseRunner t -> ParserChain2 t t -> ParseRunner t
teeParse start continueChain = do
	let startAndContinue startResult = do
		let continue = continueChain startResult.target startResult.parsed
		let continueResults = continue <<< startResult.state
		let prependStartResult continuedResult = continuedResult{
			parsed = Text.concat [startResult.parsed, continuedResult.parsed] }
		startResult : map prependStartResult continueResults
	concatMap startAndContinue . start

-- instances

deriving instance Show State

instance Show t => Show (Result t) where
	show Result{..} = show parsed ++ " as " ++ show target ++ " => " ++ show state

instance Messagable State where
	-- TODO: consider printing the context separately if a certain debug level is enabled.
	msg State{..} = "post-" ++ map toLower (show spaceState) ++ " " ++ msgShow rest

-- exported

parse :: Parser t -> ParseRunner t
parse parser state = debugStart $ debugResults $ parser.run state
	where
		debugStart :: (a -> a)
		debugStart = if null parser.name then id else
			debug ("Attempting to parse " ++ parser.name ++ " from " ++ msg state ++ "...")
		debugResults :: [a] -> [a]
		debugResults results = if null parser.name then results else
			debug ((if null results then "No" else show $ length results) ++
				" results parsing " ++ parser.name) results

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
(<<<) :: (Parser t -> ParseRunner t)
(<<<) = parse
infix 0 <<<

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

-- "And Chain 2": parse with the first, then chain to the second, and return the result targets as a pair.
(>:\\>) :: Parser t -> ParserChain2 t u -> Parser (t, u)
(>:\\>) first secondChain =
	first.name ++ " and ?" @>
		andParse first.run secondChain
infixl 3 >:\\>

-- "And Chain 2": parse with the first, then chain to the second, and return the result targets as a pair.
(>:\>) :: Parser t -> ParserChain1 t u -> Parser (t, u)
(>:\>) first secondChain = first >:\\> \t _ -> secondChain t
infixl 3 >:\>

-- "And": parse with the first, then the second, and return the result targets as a pair.
(>:>) :: Parser t -> Parser u -> Parser (t, u)
(>:>) first second = first.name ++ " and " ++ second.name @>
	andParse first.run \_ _ -> second
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
(>^\\>) :: Parser t -> ParserChain2 t t -> Parser t
(>^\\>) start continueChain =
	start.name ++ " teed to ?" @>
		teeParse start.run continueChain
infixl 2 >^\\>

-- "Tee 1"
(>^\>) :: Parser t -> ParserChain1 t t -> Parser t
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