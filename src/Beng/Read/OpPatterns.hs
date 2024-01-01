module Beng.Read.OpPatterns (
	readAllMatches
) where

import Utils.Readers (MultiReader)

import qualified Beng.Read.OpPatterns.OpAnd as OpAnd (readAllMatches)
import qualified Beng.Read.OpPatterns.OpDelimited as OpDelimited (readAllMatches)
import qualified Beng.Read.OpPatterns.OpEmpty as OpEmpty (readAllMatches)
import qualified Beng.Read.OpPatterns.OpLiteral as OpLiteral (readAllMatches)
import qualified Beng.Read.OpPatterns.OpOr as OpOr (readAllMatches)
import qualified Beng.Read.OpPatterns.OpSpace as OpSpace (readAllMatches)
import Beng.Types.OpPatterns (OpPattern(..))

import Data.Text.Lazy (Text)

-- Theory note: no OpPatterns can contain OpArgs; OpArgs can never be in any kind of "optional" group and will be included in `argsAndSuffixes` rather than `OpAnd`s.
-- In the future, the Maybe will become a list so that all possible matches can be given and the tuple at the end will include capturing group data (Map String String).
readAllMatches ::
	OpPattern ->  -- ^ The OpPattern to attempt to parse from the beginning of some text
	Bool ->       -- ^ The previous character exists (i.e., not the start of code) and is alphanumeric
	MultiReader Text
readAllMatches OpEmpty _ = OpEmpty.readAllMatches
readAllMatches OpSpace an = OpSpace.readAllMatches an
readAllMatches (OpOr subpatterns) an = OpOr.readAllMatches subpatterns an
readAllMatches (OpAnd subpatterns) an = OpAnd.readAllMatches subpatterns an
readAllMatches (OpLiteral literal) _ = OpLiteral.readAllMatches literal
readAllMatches (OpDelimited delimiter delimitend) an = OpDelimited.readAllMatches delimiter delimitend an
