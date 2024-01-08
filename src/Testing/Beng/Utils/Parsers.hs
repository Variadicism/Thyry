module Testing.Beng.Utils.Parsers (
	assertRest
) where

import Utils.Errors
import Utils.Testing

import Beng.Parse.Types.Parsers (Result(..), State(..))

import Data.Text.Lazy (Text)

assertRest :: Text -> Result a -> Fallible ()
assertRest expected result = (result.state.rest, expected) `isEqualElse`
	"The text remaining after parsing was not expected!"