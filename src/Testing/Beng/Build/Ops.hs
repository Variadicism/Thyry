module Testing.Beng.Build.Ops (
	testBuildOp
) where

import Utils.Testing

import qualified Testing.Beng.Utils.Build as Test
import Testing.Beng.Utils.Mocks (a, b, assertAdd, assertAddWords, assertApp, assertDiv, assertExp, mockABCD)
import Testing.Beng.Utils.Ops ()
import Testing.Beng.Utils.Parsers (assertRest)

import Beng.Ops (Op)
import Beng.Parse.Parsers (Result(..))

import Data.Text.Lazy (Text)

build :: Text -> [Result Op]
build = Test.build mockABCD

-- tests

testBuildOp :: TestCategory
testBuildOp = TestCategories "build Op" [
	PureTests "prefixed nullary" [
		("one exactly", do
			result <- assert1 "result" $ build "a"
			a.null result.target
			assertRest "" result),
		("one then junk", do
			result <- assert1 "result" $ build "aj"
			a.null result.target
			assertRest "j" result),
		("junk then one", do
			assert0 "results" $ build "ja"),
		("empty", do
			assert0 "results" $ build "")],
	PureTests "nonprefixed lefty equal precedence" [
		("one exactly", do
			(aResult, divResult) <- assert2 "results" $ build "a/a"
			a.null aResult.target
			assertRest "/a" aResult
			assertDiv a.null.op a.null.op divResult.target
			assertRest "" divResult),
		("twice exactly", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "a/b/a"
			a.null aResult.target
			assertRest "/b/a" aResult
			assertDiv a.null.op b.null.op divResult.target
			assertRest "/a" divResult
			assertDiv (assertDiv.op a.null.op b.null.op) a.null.op fullResult.target
			assertRest "" fullResult),
		("twice then junk", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "a/b/a{}"
			a.null aResult.target
			assertRest "/b/a{}" aResult
			assertDiv a.null.op b.null.op divResult.target
			assertRest "/a{}" divResult
			assertDiv (assertDiv.op a.null.op b.null.op) a.null.op fullResult.target
			assertRest "{}" fullResult)],
	PureTests "nonprefixed righty equal precedence" [
		("one exactly", do
			(aResult, appResult) <- assert2 "results" $ build "a$a"
			a.null aResult.target
			assertRest "$a" aResult
			assertApp a.null.op a.null.op appResult.target
			assertRest "" appResult),
		("twice exactly", do
			(aResult, appResult, fullResult) <- assert3 "results" $ build "a$b$a"
			a.null aResult.target
			assertRest "$b$a" aResult
			assertApp a.null.op b.null.op appResult.target
			assertRest "$a" appResult
			assertApp a.null.op (assertApp.op b.null.op a.null.op) fullResult.target
			assertRest "" fullResult),
		("twice then junk", do
			(aResult, appResult, fullResult) <- assert3 "results" $ build "a$b$a{}"
			a.null aResult.target
			assertRest "$b$a{}" aResult
			assertApp a.null.op b.null.op appResult.target
			assertRest "$a{}" appResult
			assertApp a.null.op (assertApp.op b.null.op a.null.op) fullResult.target
			assertRest "{}" fullResult)],
	PureTests "nonprefixed ascending precedence" [
		("precedence ascending once exactly", do
			(aResult, addResult, fullResult) <- assert3 "results" $ build "b+b/a"
			b.null aResult.target
			assertRest "+b/a" aResult
			assertAdd b.null.op b.null.op addResult.target
			assertRest "/a" addResult
			assertAdd b.null.op (assertDiv.op b.null.op a.null.op) fullResult.target
			assertRest "" fullResult),
		("precedence ascending twice exactly", do
			(aResult, addResult, addDivResult, fullResult) <- assert4 "results" $ build "a+a/b^b"
			a.null aResult.target
			assertRest "+a/b^b" aResult
			assertAdd a.null.op a.null.op addResult.target
			assertRest "/b^b" addResult
			assertAdd a.null.op (assertDiv.op a.null.op b.null.op) addDivResult.target
			assertRest "^b" addDivResult
			assertAdd
				a.null.op
				(assertDiv.op a.null.op (assertExp.op b.null.op b.null.op))
				fullResult.target
			assertRest "" fullResult),
		("precedence ascending after suffixed once exactly", do
			(aResult, addResult, fullResult) <- assert3 "results" $ build "a and a added/b"
			a.null aResult.target
			assertRest " and a added/b" aResult
			assertAddWords a.null.op a.null.op addResult.target
			assertRest "/b" addResult
			assertDiv (assertAddWords.op a.null.op a.null.op) b.null.op fullResult.target
			assertRest "" fullResult)],
	PureTests "nonprefixed descending precedence" [
		("precedence descending once exactly", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "b/b+a"
			b.null aResult.target
			assertRest "/b+a" aResult
			assertDiv b.null.op b.null.op divResult.target
			assertRest "+a" divResult
			assertAdd (assertDiv.op b.null.op b.null.op) a.null.op fullResult.target
			assertRest "" fullResult),
		("precedence descending twice exactly", do
			(aResult, expResult, divExpResult, fullResult) <- assert4 "results" $ build "a^b/a+a"
			a.null aResult.target
			assertRest "^b/a+a" aResult
			assertExp a.null.op b.null.op expResult.target
			assertRest "/a+a" expResult
			assertDiv (assertExp.op a.null.op b.null.op) a.null.op divExpResult.target
			assertRest "+a" divExpResult
			assertAdd
				(assertDiv.op (assertExp.op a.null.op b.null.op) a.null.op)
				a.null.op
				fullResult.target
			assertRest "" fullResult)],
	PureTests "nonprefixed mixed precedence" [
		("precedence down then up exactly", do
			(aResult, divResult, addDivResult, fullResult) <- assert4 "results" $ build "a/b+b^a"
			a.null aResult.target
			assertRest "/b+b^a" aResult
			assertDiv a.null.op b.null.op divResult.target
			assertRest "+b^a" divResult
			assertAdd (assertDiv.op a.null.op b.null.op) b.null.op addDivResult.target
			assertRest "^a" addDivResult
			assertAdd (assertDiv.op a.null.op b.null.op) (assertExp.op b.null.op a.null.op) fullResult.target
			assertRest "" fullResult),
		("precedence up then down exactly", do
			(aResult, addResult, addDivResult, fullResult) <- assert4 "results" $ build "a+a/b+a"
			a.null aResult.target
			assertRest "+a/b+a" aResult
			assertAdd a.null.op a.null.op addResult.target
			assertRest "/b+a" addResult
			assertAdd a.null.op (assertDiv.op a.null.op b.null.op) addDivResult.target
			assertRest "+a" addDivResult
			assertAdd
				(assertAdd.op a.null.op (assertDiv.op a.null.op b.null.op))
				a.null.op fullResult.target
			assertRest "" fullResult),
		("precedence down then up then junk", do
			(aResult, divResult, addDivResult, fullResult) <- assert4 "results" $ build "a/b+b^a!!"
			a.null aResult.target
			assertRest "/b+b^a!!" aResult
			assertDiv a.null.op b.null.op divResult.target
			assertRest "+b^a!!" divResult
			assertAdd (assertDiv.op a.null.op b.null.op) b.null.op addDivResult.target
			assertRest "^a!!" addDivResult
			assertAdd (assertDiv.op a.null.op b.null.op) (assertExp.op b.null.op a.null.op) fullResult.target
			assertRest "!!" fullResult),
		("precedence up then down then junk", do
			(aResult, addResult, addDivResult, fullResult) <- assert4 "results" $ build "a+a/b+a?"
			a.null aResult.target
			assertRest "+a/b+a?" aResult
			assertAdd a.null.op a.null.op addResult.target
			assertRest "/b+a?" addResult
			assertAdd a.null.op (assertDiv.op a.null.op b.null.op) addDivResult.target
			assertRest "+a?" addDivResult
			assertAdd
				(assertAdd.op a.null.op (assertDiv.op a.null.op b.null.op))
				a.null.op fullResult.target
			assertRest "?" fullResult),
		("precedence down then up then down further exactly", do
			(aResult, expResult, divExpResult, divExpExpResult, fullResult) <-
				assert5 "results" $ build "a^b/b^b$a"
			a.null aResult.target
			assertExp a.null.op b.null.op expResult.target
			assertDiv (assertExp.op a.null.op b.null.op) b.null.op divExpResult.target
			assertDiv (assertExp.op a.null.op b.null.op) (assertExp.op b.null.op b.null.op) divExpExpResult.target
			assertApp
				(assertDiv.op (assertExp.op a.null.op b.null.op) (assertExp.op b.null.op b.null.op))
				a.null.op fullResult.target),
		("precedence down then up then down but higher than first exactly", do
			(aResult, expResult, appExpResult, appExpExpResult, fullResult) <-
				assert5 "results" $ build "a^b$b^b/a"
			a.null aResult.target
			assertExp a.null.op b.null.op expResult.target
			assertApp (assertExp.op a.null.op b.null.op) b.null.op appExpResult.target
			assertApp (assertExp.op a.null.op b.null.op) (assertExp.op b.null.op b.null.op) appExpExpResult.target
			assertApp
				(assertExp.op a.null.op b.null.op)
				(assertDiv.op (assertExp.op b.null.op b.null.op) a.null.op)
				fullResult.target)],
	PureTests "nonprefixed mixed associativity" [
		("unequal lefty then righty exactly", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "a/b$b"
			a.null aResult.target
			assertRest "/b$b" aResult
			assertDiv a.null.op b.null.op divResult.target
			assertRest "$b" divResult
			assertApp (assertDiv.op a.null.op b.null.op) b.null.op fullResult.target
			assertRest "" fullResult),
		("unequal righty then lefty exactly", do
			(aResult, appResult, fullResult) <- assert3 "results" $ build "a$b/b"
			a.null aResult.target
			assertRest "$b/b" aResult
			assertApp a.null.op b.null.op appResult.target
			assertRest "/b" appResult
			assertApp a.null.op (assertDiv.op b.null.op b.null.op) fullResult.target
			assertRest "" fullResult),
		("unequal lefty then righty then junk", do
			(aResult, divResult, fullResult) <- assert3 "results" $ build "a/b$bl"
			a.null aResult.target
			assertRest "/b$bl" aResult
			assertDiv a.null.op b.null.op divResult.target
			assertRest "$bl" divResult
			assertApp (assertDiv.op a.null.op b.null.op) b.null.op fullResult.target
			assertRest "l" fullResult),
		("unequal righty then lefty then junk", do
			(aResult, appResult, fullResult) <- assert3 "results" $ build "a$b/bkk"
			a.null aResult.target
			assertRest "$b/bkk" aResult
			assertApp a.null.op b.null.op appResult.target
			assertRest "/bkk" appResult
			assertApp a.null.op (assertDiv.op b.null.op b.null.op) fullResult.target
			assertRest "kk" fullResult),
		-- Note: in the mocks, `$` and `+` have equal precedence for these tests.
		("equal lefty then righty exactly", do
			(aResult, addResult) <- assert2 "results" $ build "a+b$a"
			a.null aResult.target
			assertRest "+b$a" aResult
			assertAdd a.null.op b.null.op addResult.target
			assertRest "$a" addResult),
		("equal righty then lefty exactly", do
			(bResult, appResult) <-assert2 "results" $ build "b$b+a"
			b.null bResult.target
			assertRest "$b+a" bResult
			assertApp b.null.op b.null.op appResult.target
			assertRest "+a" appResult)]]