module Testing.Beng.Utils.Build (
	build
) where

import qualified Utils.Populace as P

import Testing.Beng.Utils.Parsers ((!>>>), MockParser)

import qualified Beng.Build.Ops as Op
import Beng.Build.Types.Context (Context)
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers (Parse(..))
import Beng.Types.Ops (Op)
import qualified Beng.Types.Ops as Op

import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text
import GHC.Int (Int64)

-- private

sortParses :: Parse Op -> Parse Op -> Ordering
sortParses r1 r2 = compare (getTextLength r1) (getTextLength r2)
	where
		getTextLength :: Parse Op -> Int64
		getTextLength = Text.length . Match.getText . Op.match . target

-- exported

build :: Context -> MockParser Op
build mockContext = \mockCode ->
	fmap (P.sortBy sortParses) $
		(mockContext !>>> Op.build (unpack mockCode))
		mockCode