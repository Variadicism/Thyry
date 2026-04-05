module Testing.Beng.Utils.Build (
	build
) where

import qualified Utils.Populace as P

import Testing.Beng.Utils.Parsers ((!>>>), MockParser)

import qualified Beng.Build.Invocations as Inv
import Beng.Invocations (toCode)
import Beng.Types.Build.Context (Context)
import Beng.Parse.Parsers.Code (Parse, target)
import Beng.Types.Invocations (SomeInvocation)

import Data.Text.Lazy (unpack)
import qualified Data.Text.Lazy as Text
import GHC.Int (Int64)

-- private

sortParses :: Parse SomeInvocation -> Parse SomeInvocation -> Ordering
sortParses r1 r2 = compare (getTextLength r1) (getTextLength r2)
	where
		getTextLength :: Parse SomeInvocation -> Int64
		getTextLength = Text.length . toCode . target

-- exported

build :: Context -> MockParser SomeInvocation
build mockContext = \mockCode ->
	fmap (P.sortBy sortParses) $
		(mockContext !>>> Inv.build (unpack mockCode))
		mockCode
