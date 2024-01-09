module Testing.Beng.Utils.Parsers (
	assertSpace,
	assertState,
	assertRest
) where

import Utils.Errors
import Utils.Testing

import Beng.Parse.Types.Parsers (Result(..), SpaceState, State(..))

import Data.Text.Lazy (Text)

assertSpace :: SpaceState -> Result a -> Fallible ()
assertSpace expected result = (expected, result.state.spaceState) `isEqualElse`
	"The SpaceState after parsing was unexpected!"

assertState :: SpaceState -> Text -> Result a -> Fallible ()
assertState spaceState rest result = do
	assertRest rest result
	assertSpace spaceState result

assertRest :: Text -> Result a -> Fallible ()
assertRest expected result = (expected, result.state.rest) `isEqualElse`
	"The text remaining after parsing was unexpected!"