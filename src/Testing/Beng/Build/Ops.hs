module Testing.Beng.Build.Ops (
	testBuildOp
) where

import Utils.Testing

import Testing.Beng.Utils.Mocks (a, mockABDivision)
import Testing.Beng.Utils.Ops (assertOp)
import Testing.Beng.Utils.Parsers (assertRest)

import Beng.Types.Ops (Op)
import qualified Beng.Build.Ops as Op
import Beng.Parse.Parsers ((<<<), Result(..), SpaceState(..), State(..))

import Data.Text.Lazy (Text, unpack)

-- private

build :: Text -> [Result Op]
build mockCode = Op.build (unpack mockCode) <<<
	State { context = mockABDivision, spaceState = Space, rest = mockCode }

-- tests

testBuildOp :: TestCategory
testBuildOp = PureTests "build Op" [
	("read one nullary op that covers the entire code", do
		result <- assert1 "result" $ build "a"
		assertOp a [] result.target
		assertRest "" result),
	("read one nullary op with some random stuff after it", do
		result <- assert1 "result" $ build "aj"
		assertOp a [] result.target
		assertRest "j" result),
	("return no parses if the code does not start with a known op", do
		assert0 "results" $ build "ja"),
	("return no parses for an empty code string", do
		assert0 "results" $ build "")]