module Testing.Beng.Build.NonPrefixed (
	testBuildNonPrefixed
) where

import Utils.Fallible
import Utils.Messaging (msg)
import qualified Utils.Populace as P
import Utils.Testing

import qualified Testing.Beng.Utils.Build as Test
import Testing.Beng.Utils.Mocks (a, b, assertAdd, assertAddWords, assertApp, assertDiv, assertExp, mockABCD)
import Testing.Beng.Utils.Ops ()
import Testing.Beng.Utils.Parsers (assertRest)

import Beng.Ops (Op)
import Beng.Parse.Parsers.Code (Parse, target)

import Data.Text.Lazy (Text)

build :: Text -> Fallible [Parse Op]
build mockCode =
	prependToError
		("An unexpected error occurred while building the mock code, " ++ show mockCode ++ "!") $
	mapError msg $
	fmap P.toList $
	Test.build mockABCD mockCode

-- tests

testBuildNonPrefixed :: TestCategory
testBuildNonPrefixed = TestCategories "build non-repfixed Op" [
	PureTests "lefty equal precedence" [
		("one exactly", do
			(aParse, divParse) <- assert2 "results" =<< build "a/a"
			a.null aParse.target
			assertRest "/a" aParse
			assertDiv a.null.op a.null.op divParse.target
			assertRest "" divParse),
		("twice exactly", do
			(aParse, divParse, fullParse) <- assert3 "results" =<< build "a/b/a"
			a.null aParse.target
			assertRest "/b/a" aParse
			assertDiv a.null.op b.null.op divParse.target
			assertRest "/a" divParse
			assertDiv (assertDiv.op a.null.op b.null.op) a.null.op fullParse.target
			assertRest "" fullParse),
		("twice then junk", do
			(aParse, divParse, fullParse) <- assert3 "results" =<< build "a/b/a{}"
			a.null aParse.target
			assertRest "/b/a{}" aParse
			assertDiv a.null.op b.null.op divParse.target
			assertRest "/a{}" divParse
			assertDiv (assertDiv.op a.null.op b.null.op) a.null.op fullParse.target
			assertRest "{}" fullParse)],
	PureTests "righty equal precedence" [
		("one exactly", do
			(aParse, appParse) <- assert2 "results" =<< build "a$a"
			a.null aParse.target
			assertRest "$a" aParse
			assertApp a.null.op a.null.op appParse.target
			assertRest "" appParse),
		("twice exactly", do
			(aParse, appParse, fullParse) <- assert3 "results" =<< build "a$b$a"
			a.null aParse.target
			assertRest "$b$a" aParse
			assertApp a.null.op b.null.op appParse.target
			assertRest "$a" appParse
			assertApp a.null.op (assertApp.op b.null.op a.null.op) fullParse.target
			assertRest "" fullParse),
		("twice then junk", do
			(aParse, appParse, fullParse) <- assert3 "results" =<< build "a$b$a{}"
			a.null aParse.target
			assertRest "$b$a{}" aParse
			assertApp a.null.op b.null.op appParse.target
			assertRest "$a{}" appParse
			assertApp a.null.op (assertApp.op b.null.op a.null.op) fullParse.target
			assertRest "{}" fullParse)],
	PureTests "ascending precedence" [
		("precedence ascending once exactly", do
			(aParse, addParse, fullParse) <- assert3 "results" =<< build "b+b/a"
			b.null aParse.target
			assertRest "+b/a" aParse
			assertAdd b.null.op b.null.op addParse.target
			assertRest "/a" addParse
			assertAdd b.null.op (assertDiv.op b.null.op a.null.op) fullParse.target
			assertRest "" fullParse),
		("precedence ascending twice exactly", do
			(aParse, addParse, addDivParse, fullParse) <- assert4 "results" =<< build "a+a/b^b"
			a.null aParse.target
			assertRest "+a/b^b" aParse
			assertAdd a.null.op a.null.op addParse.target
			assertRest "/b^b" addParse
			assertAdd a.null.op (assertDiv.op a.null.op b.null.op) addDivParse.target
			assertRest "^b" addDivParse
			assertAdd
				a.null.op
				(assertDiv.op a.null.op (assertExp.op b.null.op b.null.op))
				fullParse.target
			assertRest "" fullParse),
		("precedence ascending after suffixed once exactly", do
			(aParse, addParse, fullParse) <- assert3 "results" =<< build "a and a added/b"
			a.null aParse.target
			assertRest " and a added/b" aParse
			assertAddWords a.null.op a.null.op addParse.target
			assertRest "/b" addParse
			assertDiv (assertAddWords.op a.null.op a.null.op) b.null.op fullParse.target
			assertRest "" fullParse)],
	PureTests "descending precedence" [
		("precedence descending once exactly", do
			(aParse, divParse, fullParse) <- assert3 "results" =<< build "b/b+a"
			b.null aParse.target
			assertRest "/b+a" aParse
			assertDiv b.null.op b.null.op divParse.target
			assertRest "+a" divParse
			assertAdd (assertDiv.op b.null.op b.null.op) a.null.op fullParse.target
			assertRest "" fullParse),
		("precedence descending twice exactly", do
			(aParse, expParse, divExpParse, fullParse) <- assert4 "results" =<< build "a^b/a+a"
			a.null aParse.target
			assertRest "^b/a+a" aParse
			assertExp a.null.op b.null.op expParse.target
			assertRest "/a+a" expParse
			assertDiv (assertExp.op a.null.op b.null.op) a.null.op divExpParse.target
			assertRest "+a" divExpParse
			assertAdd
				(assertDiv.op (assertExp.op a.null.op b.null.op) a.null.op)
				a.null.op
				fullParse.target
			assertRest "" fullParse)],
	PureTests "mixed precedence" [
		("precedence down then up exactly", do
			(aParse, divParse, addDivParse, fullParse) <- assert4 "results" =<< build "a/b+b^a"
			a.null aParse.target
			assertRest "/b+b^a" aParse
			assertDiv a.null.op b.null.op divParse.target
			assertRest "+b^a" divParse
			assertAdd (assertDiv.op a.null.op b.null.op) b.null.op addDivParse.target
			assertRest "^a" addDivParse
			assertAdd (assertDiv.op a.null.op b.null.op) (assertExp.op b.null.op a.null.op) fullParse.target
			assertRest "" fullParse),
		("precedence up then down exactly", do
			(aParse, addParse, addDivParse, fullParse) <- assert4 "results" =<< build "a+a/b+a"
			a.null aParse.target
			assertRest "+a/b+a" aParse
			assertAdd a.null.op a.null.op addParse.target
			assertRest "/b+a" addParse
			assertAdd a.null.op (assertDiv.op a.null.op b.null.op) addDivParse.target
			assertRest "+a" addDivParse
			assertAdd
				(assertAdd.op a.null.op (assertDiv.op a.null.op b.null.op))
				a.null.op fullParse.target
			assertRest "" fullParse),
		("precedence down then up then junk", do
			(aParse, divParse, addDivParse, fullParse) <- assert4 "results" =<< build "a/b+b^a!!"
			a.null aParse.target
			assertRest "/b+b^a!!" aParse
			assertDiv a.null.op b.null.op divParse.target
			assertRest "+b^a!!" divParse
			assertAdd (assertDiv.op a.null.op b.null.op) b.null.op addDivParse.target
			assertRest "^a!!" addDivParse
			assertAdd (assertDiv.op a.null.op b.null.op) (assertExp.op b.null.op a.null.op) fullParse.target
			assertRest "!!" fullParse),
		("precedence up then down then junk", do
			(aParse, addParse, addDivParse, fullParse) <- assert4 "results" =<< build "a+a/b+a?"
			a.null aParse.target
			assertRest "+a/b+a?" aParse
			assertAdd a.null.op a.null.op addParse.target
			assertRest "/b+a?" addParse
			assertAdd a.null.op (assertDiv.op a.null.op b.null.op) addDivParse.target
			assertRest "+a?" addDivParse
			assertAdd
				(assertAdd.op a.null.op (assertDiv.op a.null.op b.null.op))
				a.null.op fullParse.target
			assertRest "?" fullParse),
		("precedence down then up then down further exactly", do
			(aParse, expParse, divExpParse, divExpExpParse, fullParse) <-
				assert5 "results" =<< build "a^b/b^b$a"
			a.null aParse.target
			assertExp a.null.op b.null.op expParse.target
			assertDiv (assertExp.op a.null.op b.null.op) b.null.op divExpParse.target
			assertDiv (assertExp.op a.null.op b.null.op) (assertExp.op b.null.op b.null.op) divExpExpParse.target
			assertApp
				(assertDiv.op (assertExp.op a.null.op b.null.op) (assertExp.op b.null.op b.null.op))
				a.null.op fullParse.target),
		("precedence down then up then down but higher than first exactly", do
			(aParse, expParse, appExpParse, appExpExpParse, fullParse) <-
				assert5 "results" =<< build "a^b$b^b/a"
			a.null aParse.target
			assertExp a.null.op b.null.op expParse.target
			assertApp (assertExp.op a.null.op b.null.op) b.null.op appExpParse.target
			assertApp (assertExp.op a.null.op b.null.op) (assertExp.op b.null.op b.null.op) appExpExpParse.target
			assertApp
				(assertExp.op a.null.op b.null.op)
				(assertDiv.op (assertExp.op b.null.op b.null.op) a.null.op)
				fullParse.target)],
	PureTests "mixed associativity" [
		("unequal lefty then righty exactly", do
			(aParse, divParse, fullParse) <- assert3 "results" =<< build "a/b$b"
			a.null aParse.target
			assertRest "/b$b" aParse
			assertDiv a.null.op b.null.op divParse.target
			assertRest "$b" divParse
			assertApp (assertDiv.op a.null.op b.null.op) b.null.op fullParse.target
			assertRest "" fullParse),
		("unequal righty then lefty exactly", do
			(aParse, appParse, fullParse) <- assert3 "results" =<< build "a$b/b"
			a.null aParse.target
			assertRest "$b/b" aParse
			assertApp a.null.op b.null.op appParse.target
			assertRest "/b" appParse
			assertApp a.null.op (assertDiv.op b.null.op b.null.op) fullParse.target
			assertRest "" fullParse),
		("unequal lefty then righty then junk", do
			(aParse, divParse, fullParse) <- assert3 "results" =<< build "a/b$bl"
			a.null aParse.target
			assertRest "/b$bl" aParse
			assertDiv a.null.op b.null.op divParse.target
			assertRest "$bl" divParse
			assertApp (assertDiv.op a.null.op b.null.op) b.null.op fullParse.target
			assertRest "l" fullParse),
		("unequal righty then lefty then junk", do
			(aParse, appParse, fullParse) <- assert3 "results" =<< build "a$b/bkk"
			a.null aParse.target
			assertRest "$b/bkk" aParse
			assertApp a.null.op b.null.op appParse.target
			assertRest "/bkk" appParse
			assertApp a.null.op (assertDiv.op b.null.op b.null.op) fullParse.target
			assertRest "kk" fullParse),
		-- Note: in the mocks, `$` and `+` have equal precedence for these tests.
		("equal lefty then righty exactly", do
			(aParse, addParse) <- assert2 "results" =<< build "a+b$a"
			a.null aParse.target
			assertRest "+b$a" aParse
			assertAdd a.null.op b.null.op addParse.target
			assertRest "$a" addParse),
		("equal righty then lefty exactly", do
			(bParse, appParse) <-assert2 "results" =<< build "b$b+a"
			b.null bParse.target
			assertRest "$b+a" bParse
			assertApp b.null.op b.null.op appParse.target
			assertRest "+a" appParse)]]