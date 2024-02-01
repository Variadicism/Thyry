module Testing.Beng.Utils.Parsers (
	MockParser,
	(!>>>),
	assertSpace,
	assertState,
	assertRest
) where

import Utils.Fallible
import Utils.Messaging (msg)
import Utils.Populace (Populace)
import Utils.Testing

import Beng.Build.Types.Context (Context)
import Beng.Parse.Parsers ((>>>), Parse(..), Parser, SpaceState, State(..), fileStartState)

import Data.Text.Lazy (Text)

-- types

-- Unlike Parser's Results, the Error in the Fallible is a simple String for testing.
type MockParser a = Text -> Fallible (Populace (Parse a))

-- exported

(!>>>) :: Show a => Context -> Parser a -> MockParser a
(!>>>) mockContext parser = \mockCode ->
	mapError msg $ (fileStartState "[TEST]" mockContext mockCode >>> parser)
infix 0 !>>>

assertSpace :: SpaceState -> Parse a -> Fallible ()
assertSpace expected result = (expected, result.state.spaceState) `isEqualElse`
	"The SpaceState after parsing was unexpected!"

assertState :: SpaceState -> Text -> Parse a -> Fallible ()
assertState spaceState rest result = do
	assertRest rest result
	assertSpace spaceState result

assertRest :: Text -> Parse a -> Fallible ()
assertRest expected result = (expected, result.state.rest) `isEqualElse`
	"The text remaining after parsing was unexpected!"