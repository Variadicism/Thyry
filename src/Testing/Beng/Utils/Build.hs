module Testing.Beng.Utils.Build (
	build
) where

import qualified Beng.Build.Ops as Op
import Beng.Build.Types.Context (Context)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((<<<), Result(..), fileStartState)
import Beng.Types.Ops (Op)
import qualified Beng.Types.Ops as Op

import Data.List (sortBy)
import Data.Text.Lazy (Text, unpack)
import qualified Data.Text.Lazy as Text
import GHC.Int (Int64)

-- private

sortResults :: Result Op -> Result Op -> Ordering
sortResults r1 r2 = compare (getTextLength r1) (getTextLength r2)
	where
		getTextLength :: Result Op -> Int64
		getTextLength = Text.length . Match.getText . Op.match . target

-- exported

build :: Context -> Text -> [Result Op]
build mockContext mockCode = sortBy sortResults (
	Op.build (unpack mockCode) <<<
	fileStartState "Test" mockContext mockCode)