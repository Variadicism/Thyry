module Testing.Beng.Build.Ops (
	testBuildOp
) where

import Utils.Testing

import Testing.Beng.Utils.Mocks (a, b, assertAddArgs, assertAddArgsEq, assertAddWordsArgsEq, assertAppArgs, assertAppArgsEq, assertDivArgs, assertDivArgsEq, assertExpArgsEq, mockABAddDivExpApp)
import Testing.Beng.Utils.Ops (assertArgEq, assertOp)
import Testing.Beng.Utils.Parsers (assertRest)

import Beng.Ops (Op)
import qualified Beng.Ops as Op
import qualified Beng.Build.Ops as Op
import qualified Beng.Parse.Matches as Match
import Beng.Parse.Parsers ((<<<), Result(..), fileStartState)

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

build :: Text -> [Result Op]
build mockCode = sortBy sortResults (
	Op.build (unpack mockCode) <<<
	fileStartState mockABAddDivExpApp mockCode)

-- tests

testBuildOp :: TestCategory
testBuildOp = TestCategories "build Op" [
	PureTests "prefixed nullary" [
		("one exactly", do
			result <- assert1 "result" $ build "a"
			assertOp a [] result.target
			assertRest "" result),
		("one then junk", do
			result <- assert1 "result" $ build "aj"
			assertOp a [] result.target
			assertRest "j" result),
		("junk then one", do
			assert0 "results" $ build "ja"),
		("empty", do
			assert0 "results" $ build "")],
	PureTests "nonprefixed lefty equal precedence" [
		("one exactly", do
			(aResult, divResult) <- assert2 "results" $ build "a/a"
			assertOp a [] aResult.target
			assertRest "/a" aResult
			assertDivArgsEq a a divResult.target
			assertRest "" divResult),
		("twice exactly", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "a/b/a"
			assertOp a [] aResult.target
			assertRest "/b/a" aResult
			assertDivArgsEq a b divResult.target
			assertRest "/a" divResult
			assertDivArgs (assertDivArgsEq a b) (assertArgEq "Divisor" a) fullResult.target
			assertRest "" fullResult),
		("twice then junk", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "a/b/a{}"
			assertOp a [] aResult.target
			assertRest "/b/a{}" aResult
			assertDivArgsEq a b divResult.target
			assertRest "/a{}" divResult
			assertDivArgs (assertDivArgsEq a b) (assertArgEq "Divisor" a) fullResult.target
			assertRest "{}" fullResult)],
	PureTests "nonprefixed righty equal precedence" [
		("one exactly", do
			(aResult, appResult) <- assert2 "results" $ build "a$a"
			assertOp a [] aResult.target
			assertRest "$a" aResult
			assertAppArgsEq a a appResult.target
			assertRest "" appResult),
		("twice exactly", do
			(aResult, appResult, fullResult) <- assert3 "results" $ build "a$b$a"
			assertOp a [] aResult.target
			assertRest "$b$a" aResult
			assertAppArgsEq a b appResult.target
			assertRest "$a" appResult
			assertAppArgs (assertArgEq "Left" a) (assertAppArgsEq b a) fullResult.target
			assertRest "" fullResult),
		("twice then junk", do
			(aResult, appResult, fullResult) <- assert3 "results" $ build "a$b$a{}"
			assertOp a [] aResult.target
			assertRest "$b$a{}" aResult
			assertAppArgsEq a b appResult.target
			assertRest "$a{}" appResult
			assertAppArgs (assertArgEq "Left" a) (assertAppArgsEq b a) fullResult.target
			assertRest "{}" fullResult)],
	PureTests "nonprefixed ascending precedence" [
		("precedence ascending once exactly", do
			(aResult, addResult, fullResult) <- assert3 "results" $ build "b+b/a"
			assertOp b [] aResult.target
			assertRest "+b/a" aResult
			assertAddArgsEq b b addResult.target
			assertRest "/a" addResult
			assertAddArgs (assertArgEq "Augend" b) (assertDivArgsEq b a) fullResult.target
			assertRest "" fullResult),
		("precedence ascending twice exactly", do
			(aResult, addResult, addDivResult, fullResult) <- assert4 "results" $ build "a+a/b^b"
			assertOp a [] aResult.target
			assertRest "+a/b^b" aResult
			assertAddArgsEq a a addResult.target
			assertRest "/b^b" addResult
			assertAddArgs (assertArgEq "Augend" a) (assertDivArgsEq a b) addDivResult.target
			assertRest "^b" addDivResult
			assertAddArgs
				(assertArgEq "Augend" a)
				(assertDivArgs (assertArgEq "Dividend" a) (assertExpArgsEq b b))
				fullResult.target
			assertRest "" fullResult),
		("precedence ascending after suffixed once exactly", do
			(aResult, addResult, fullResult) <- assert3 "results" $ build "a and a added/b"
			assertOp a [] aResult.target
			assertRest " and a added/b" aResult
			assertAddWordsArgsEq a a addResult.target
			assertRest "/b" addResult
			assertDivArgs (assertAddWordsArgsEq a a) (assertArgEq "Divisor" b) fullResult.target
			assertRest "" fullResult)],
	PureTests "nonprefixed descending precedence" [
		("precedence descending once exactly", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "b/b+a"
			assertOp b [] aResult.target
			assertRest "/b+a" aResult
			assertDivArgsEq b b divResult.target
			assertRest "+a" divResult
			assertAddArgs (assertDivArgsEq b b) (assertArgEq "Addend" a) fullResult.target
			assertRest "" fullResult),
		("precedence descending twice exactly", do
			(aResult, expResult, divExpResult, fullResult) <- assert4 "results" $ build "a^b/a+a"
			assertOp a [] aResult.target
			assertRest "^b/a+a" aResult
			assertExpArgsEq a b expResult.target
			assertRest "/a+a" expResult
			assertDivArgs (assertExpArgsEq a b) (assertArgEq "Divisor" a) divExpResult.target
			assertRest "+a" divExpResult
			assertAddArgs
				(assertDivArgs (assertExpArgsEq a b) (assertArgEq "Divisor" a))
				(assertArgEq "Augend" a)
				fullResult.target
			assertRest "" fullResult)],
	PureTests "nonprefixed mixed associativity" [
		("unequal lefty then righty exactly", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "a/b$b"
			assertOp a [] aResult.target
			assertRest "/b$b" aResult
			assertDivArgsEq a b divResult.target
			assertRest "$b" divResult
			assertAppArgs (assertDivArgsEq a b) (assertArgEq "Right" b) fullResult.target
			assertRest "" fullResult),
		("unequal righty then lefty exactly", do
			(aResult, appResult, fullResult) <- assert3 "results" $ build "a$b/b"
			assertOp a [] aResult.target
			assertRest "$b/b" aResult
			assertAppArgsEq a b appResult.target
			assertRest "/b" appResult
			assertAppArgs (assertArgEq "Left" a) (assertDivArgsEq b b) fullResult.target
			assertRest "" fullResult),
		("unequal lefty then righty then junk", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "a/b$bl"
			assertOp a [] aResult.target
			assertRest "/b$bl" aResult
			assertDivArgsEq a b divResult.target
			assertRest "$bl" divResult
			assertAppArgs (assertDivArgsEq a b) (assertArgEq "Right" b) fullResult.target
			assertRest "l" fullResult),
		("unequal righty then lefty then junk", do
			(aResult, appResult, fullResult) <- assert3 "results" $ build "a$b/bkk"
			assertOp a [] aResult.target
			assertRest "$b/bkk" aResult
			assertAppArgsEq a b appResult.target
			assertRest "/bkk" appResult
			assertAppArgs (assertArgEq "Left" a) (assertDivArgsEq b b) fullResult.target
			assertRest "kk" fullResult),
		-- Note: in the mocks, `$` and `+` have equal precedence for these tests.
		("equal lefty then righty exactly", do
			(aResult, addResult) <- assert2 "results" $ build "a+b$a"
			assertOp a [] aResult.target
			assertRest "+b$a" aResult
			assertAddArgsEq a b addResult.target
			assertRest "$a" addResult),
		("equal righty then lefty exactly", do
			(bResult, appResult) <-assert2 "results" $ build "b$b+a"
			assertOp b [] bResult.target
			assertRest "$b+a" bResult
			assertAppArgsEq b b appResult.target
			assertRest "+a" appResult)],
	PureTests "nonprefixed mixed precedence" []]