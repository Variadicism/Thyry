module Beng.Parse.Parsers (
	Parse(..),
	Parses(..),
	Parser,  -- Do not export Parser internals.
	ParseRunner,
	State(..),
	prependToBestError,
	onParses,
	parse,
	takeAsUsing,
	parseAny,
	parseAllUsing,
	parseWhileUsing,
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
import Utils.Lists (showWithOr)
import Utils.Messaging (debugM)
import Utils.Populace (Populace(..))
import qualified Utils.Populace as P

import Beng.Ops ()
import Beng.Types.Parse.Parsers (Parse(..), Parses(..), Parser(..), ParseRunner, State(..))

import Control.Monad (when)

{- HERE is a cheat sheet for the meaning of all the crazy symbols in here:
   - <<< runs a Parser with the given State (equivalent to `parse`)
   - @ is for naming things:
      - @> combines a name with a ParseRunner to make a Parser.
      - @+> has a `+` because it adds onto an existing name.
   - > > is for piping the output of one parser into something else.
      - \ symbolizes a lambda; each one represents an expectation of an upcoming lambda variable
         - 1 \ passes the target parsed to the following function
         - 2 \\ passes the target and parsed
      - : ("and") is for running parsers sequentially and getting both results
      - - ("filter") is for filtering unwanted results (and transforming them if desired)
      - | ("or") is for running parsers from the same starting point and gathering all the results
      - ^ ("tee") is for running parsers sequentially and accepting the results of
         parsing with just the first one and parsing with both sequentially -}

-- private

type ParserChain1 e p s ti to = ti -> Parser e p s to

type ParserChain2 e p s ti to = ti -> p -> Parser e p s to

mapParseTarget :: (ti -> p -> to) -> Parse p s ti -> Parse p s to
mapParseTarget f parse = parse{ target = f parse.target parse.parsed }

mapParsesTargets :: (ti -> p -> to) -> Parses e p s ti -> Parses e p s to
mapParsesTargets = onParses . P.map . mapParseTarget

(<!?>) :: IsError e => Maybe e -> Maybe e -> Maybe e
(<!?>) e1 = \case
	Nothing -> e1
	Just e2 -> case e1 of
		Nothing -> Just e2
		Just e1 -> Just $ e1 <!> e2

onMaybeBestError :: IsError e => (Maybe e -> Maybe e) -> Parses e p s t -> Parses e p s t
onMaybeBestError f parses = parses{ bestError = f parses.bestError }

concatParses :: IsError e => (Populace (Parses e p s t) -> Parses e p s t)
-- `fold1` is safe for Populaces.
concatParses = foldl1 foldParses where
	foldParses = \prev next -> prev{
		parses = prev.parses <> next.parses,
		bestError = prev.bestError <!?> next.bestError }

prependParseUsing :: (IsError e, Semigroup p) =>
	(t -> u -> v) -> Parse p s t -> Parses e p s u -> Parses e p s v
prependParseUsing m t = onParses $ P.map (prependToParse t)
	where prependToParse = \t u -> u{
		parsed = t.parsed <> u.parsed,
		target = m t.target u.target }

getIndentation :: State p s => s -> String
getIndentation state = do
	let numberString = show $ indentation state
	let numberOfSpaces = indentation state - length numberString + 1
	numberString ++ "|" ++ replicate numberOfSpaces ' '

debugIndented state = debugM . (getIndentation state++)

andParseFrom :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show ti, Show to) =>
	String -> Parses e p s ti -> ParserChain2 e p s ti to -> ParseRunner e p s (ti, to)
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
	let mergedSubparses = P.map runSecond firstParses.parses  -- Populace (FallibleI e (Parses (t, u)))
	sequencedParses <- P.sequenceAny mergedSubparses  -- FallibleI e (Populace (Parses (t, u)))
	let pairedParses = concatParses sequencedParses  -- Parses (t, u)
	return $ onMaybeBestError (firstParses.bestError <!?>) pairedParses

andParse :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show ti, Show to) =>
	Parser e p s ti -> ParserChain2 e p s ti to -> ParseRunner e p s (ti, to)
andParse first secondChain = \state -> do
	firstParses <- state >>> first
	andParseFrom first.name firstParses secondChain state

orParseBeside :: (IsError e, State p s) =>
	String -> FallibleI e (Parses e p s t) -> String -> FallibleI e (Parses e p s t) -> ParseRunner e p s t
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

orParse :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	Parser e p s t -> Parser e p s t -> ParseRunner e p s t
orParse first second = \state ->
	orParseBeside first.name (state >>> first) second.name (state >>> second) state

teeParse :: (IsError e, Show e, Semigroup p, Show p, Show s, State p s, Show t) =>
	Parser e p s t -> ParserChain2 e p s t t -> ParseRunner e p s t
teeParse first secondChain = \state -> do
	firstParses <- state >>> first
	let teedParses = do
		secondParses <- andParseFrom first.name firstParses secondChain state
		return $ mapParsesTargets (\(_, t) _ -> t) secondParses
	orParseBeside first.name (Falue firstParses) "its tee" teedParses state

-- instances

instance (Eq p, Eq s, State p s, Eq t) => Eq (Parse p s t) where
	(==) r1 r2 = r1.parsed == r2.parsed && r1.target == r2.target && (rest r1.state) == (rest r2.state)

instance (Show p, Show s, Show t) => Show (Parse p s t) where
	show Parse{..} = show parsed ++ " as " ++ show target ++ " => " ++ show state

instance (Ord p, State p s, Eq s, Eq t, Ord t) => Ord (Parse p s t) where
	compare r1 r2 = compare r1.target r2.target <> compare (rest r1.state) (rest r2.state)

instance (Eq e, Eq p, Eq s, State p s, Eq t) => Eq (Parses e p s t) where
	(==) p1 p2 = p1.parses == p2.parses && p1.bestError == p2.bestError

instance (Show e, Show p, Show s, Show t) => Show (Parses e p s t) where
	show Parses{..} = showWithOr parses.l ++ maybe "" ((" else "++) . show) bestError

instance (Ord e, Ord p, State p s, Eq s, Eq t, Ord t) => Ord (Parses e p s t) where
	compare p1 p2 = compare p1.parses p2.parses <> compare p1.bestError p2.bestError

-- exported

prependToBestError :: IsError e => String -> (Parses e p s t -> Parses e p s t)
prependToBestError prefix = onMaybeBestError (fmap $ prepend prefix)

onParses :: (Populace (Parse p s t) -> Populace (Parse p s u)) -> Parses e p s t -> Parses e p s u
onParses f ts = ts{ parses = f ts.parses }

parse :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	Parser e p s t -> ParseRunner e p s t
parse parser = \state -> do
	when (not $ null parser.name) $ debugM $
		getIndentation state ++ "Parsing " ++ parser.name ++ " from " ++ show state ++ "..."

	let indentedResults = parser.run $ indent state
	let outdentParse = \parse -> parse{ state = outdent parse.state }
	let parses = fmap (onParses (P.map outdentParse)) indentedResults

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

type TakeAsNull e p s t = t -> ParseRunner e p s t
type TakeAs1 p s t = p -> t -> s -> Parse p s t

takeAsUsing :: (IsError e, State p s, Show s, Show t) =>
	TakeAs1 p s t -> p -> t -> ParseRunner e p s t
-- TODO: rename to "accept" or similar; I think take :: head ::: accept :: parse.
takeAsUsing takeAs1 parsed target = \state -> return Parses {
	parses = P.singleton $ takeAs1 parsed target state,
	bestError = Nothing }

parseAny :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	(Populace (Parser e p s t) -> Parser e p s t)
parseAny = foldr1 (>|>)

{- Parse as many instances of the target as possible, "teeing off" each parse
   so that each possible parse result is listed. -}
parseAllUsing :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show t) =>
	TakeAsNull e p s [t] -> Parser e p s t -> Parser e p s [t]
-- TODO: rename this to "parseGreedy" or similar; "all" sounds like "rest" should be empty at the end.
parseAllUsing takeAsNull parser = "all " ++ parser.name @> \state -> state >>>
	-- A tee's tail ignoring the output of the head is usually bad, but here,
	-- we're just losing an empty list that would have been concatenated.
	(("none of " ++ parser.name) @> takeAsNull []) >^\> \_ ->
	parser >:>
	parseAllUsing takeAsNull parser >\>
	\(next, rest) -> next:rest

parseWhileUsing :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show t) =>
	TakeAsNull e p s [t] -> String -> (s -> Bool) -> Parser e p s t -> Parser e p s [t]
parseWhileUsing takeAsNull conditionDescription shouldContinue parser =
	parser.name ++ " while " ++ conditionDescription @> \state ->
		if shouldContinue state then
			state >>>
			parser >:>
			parseWhileUsing takeAsNull conditionDescription shouldContinue parser >\>
			\(next, rest) -> next:rest
		else takeAsNull [] state

-- "Run": Run the parser with the given state and get the results.
(<<<) :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	(Parser e p s t -> ParseRunner e p s t)
(<<<) = parse
infix 0 <<<

(>>>) :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	(s -> Parser e p s t -> FallibleI e (Parses e p s t))
(>>>) = flip parse
infix 0 >>>

-- "Construct": make a parser form the name and how to run it.
(@>) :: String -> ParseRunner e p s t -> Parser e p s t
(@>) = Parser
infix 4 @>

-- "Contextualize": add contextual information to the parser's name for better debugging
(@+>) :: String -> Parser e p s t -> Parser e p s t
(@+>) context parser =
	"for " ++ context ++ ", " ++ parser.name @>
		parser.run
infix 0 @+>

-- "Update with Target": make an update to the state without affecting the target
(>/\>) :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	Parser e p s t -> (s -> t -> s) -> Parser e p s t
(>/\>) parser updater = parser.name @> \state -> do
	parses <- state >>> parser
	let update parse = parse{ state = updater parse.state parse.target }
	return $ onParses (P.map update) parses
infixl 2 >/\>

-- "Update": make an update to the state without affecting the target
(>/>) :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	Parser e p s t -> (s -> s) -> Parser e p s t
(>/>) parser updater = parser >/\> \s _ -> updater s
infixl 2 >/>

-- "And Chain 2": parse with the first, then chain to the second, and return the result targets as a pair.
(>:\\>) :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show t, Show u) =>
	Parser e p s t -> ParserChain2 e p s t u -> Parser e p s (t, u)
(>:\\>) first secondChain =
	first.name ++ " and ?" @>
		andParse first secondChain
infixl 3 >:\\>

-- "And Chain 2": parse with the first, then chain to the second, and return the result targets as a pair.
(>:\>) :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show t, Show u) =>
	Parser e p s t -> ParserChain1 e p s t u -> Parser e p s (t, u)
(>:\>) first secondChain = first >:\\> \t _ -> secondChain t
infixl 3 >:\>

-- "And": parse with the first, then the second, and return the result targets as a pair.
(>:>) :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show t, Show u) =>
	Parser e p s t -> Parser e p s u -> Parser e p s (t, u)
(>:>) first second = first.name ++ " and " ++ second.name @>
	andParse first \_ _ -> second
infixl 3 >:>

-- "Filter 2": filter out unwanted results by turning them to Nothing; transform successes if desired
(>-\\>) :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	Parser e p s t -> (t -> p -> FallibleI e u) -> Parser e p s u
(>-\\>) parser transform = parser.name ++ " filtered" @> \state -> do
	parses <- parser <<< state
	let applyFilter parse = do
		newTarget <- transform parse.target parse.parsed
		return $ parse{ target = newTarget }
	filteredParses <- P.sequenceAny $ P.map applyFilter parses.parses
	return parses{ parses = filteredParses }
	
infixl 2 >-\\>

-- "Filter 1": filter out unwanted results by turning them to Nothing; transform successes if desired
(>-\>) :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	Parser e p s t -> (t -> FallibleI e u) -> Parser e p s u
(>-\>) parser transform = parser >-\\> \t _ -> transform t
infixl 2 >-\>

-- "Or": combine the results of two parsers, i.e., parse using either parser
(>|>) :: (IsError e, Show e, Show p, State p s, Show s, Show t) =>
	Parser e p s t -> Parser e p s t -> Parser e p s t
(>|>) parser1 parser2 = 
	parser1.name ++ " or " ++ parser2.name @>
		orParse parser1 parser2
infixl 1 >|>

-- "Tee 2": use the first parser, then chain to the next, BUT accept results from the first alone AND the chain.
(>^\\>) :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show t) => 
	Parser e p s t -> ParserChain2 e p s t t -> Parser e p s t
(>^\\>) start continueChain = start.name ++ " teed to ?" @>
	teeParse start continueChain
infixl 2 >^\\>

-- "Tee 1"
(>^\>) :: (IsError e, Show e, Semigroup p, Show p, State p s, Show s, Show t) =>
	Parser e p s t -> ParserChain1 e p s t t -> Parser e p s t
(>^\>) start continueChain = start >^\\> \t _ -> continueChain t
infixl 2 >^\>

--- There is no Tee without chaining because that could silently discard previous results!

-- "Fmap 2": map the given function to each Parse using its target and parsed Text
-- This is equivalent to (>\>) except that it passes the parsed Text in addition to the target
(>\\>) :: Parser e p s t -> (t -> p -> u) -> Parser e p s u
(>\\>) parser f = parser{ run = fmap (mapParsesTargets f) . parser.run }
infixl 2 >\\>

-- "Fmap 1": map the given function to each Parse using its target
-- This is equivalent to (>\\>) excep that it does not pass the parsed Text
(>\>) :: Parser e p s t -> (t -> u) -> Parser e p s u
(>\>) parser targetMapper = parser >\\> \target _ -> targetMapper target
infixl 2 >\>