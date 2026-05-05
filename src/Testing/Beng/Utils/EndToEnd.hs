module Testing.Beng.Utils.EndToEnd (
	build,
	evaluate,
	finalResult,
	assertFinalInt,
	assertFinalString,
	assertFileReturns,
	assertFileErrors
) where

import Utils.Fallible
import Utils.Messaging (msg)
import Utils.Testing
import qualified Utils.Populace as P
import Utils.Fallible.Trans (VoidFallible, falT, tryIO)

import qualified Beng.Build.Context.Builtin as Builtin
import Beng.Build (buildCodeUsing)
import Beng.Build.Context.Builders (asInt, asNativeString)
import Beng.Run (runWhileOp)
import Beng.Types.Invocations (SomeInvocation)
import Beng.Types.Things (SomeThing(..))

import Data.Text.Lazy (Text, unpack)
import qualified Data.Text.Lazy as Text
import qualified Data.Text.Lazy.IO as TextIO

build :: Text -> Fallible [SomeInvocation]
build code = fmap P.toList $ buildCodeUsing Builtin.context (unpack code) code

evaluate :: Text -> Fallible [SomeThing]
evaluate code = do
	ops <- build code
	traverse (mapError msg . runWhileOp . SomeThing) ops

finalResult :: Text -> Fallible SomeThing
finalResult code = do
	results <- evaluate code
	case reverse results of
		lastResult:_ -> return lastResult
		[] -> Error "The built code yielded no results!"

assertFinalInt :: Int -> Text -> Fallible ()
assertFinalInt expected code = do
	result <- finalResult code
	int32 <- mapError show $ asInt result
	(expected, fromIntegral int32) `isEqualElse`
		"The final evaluated Int was unexpected!"

assertFinalString :: Text -> Text -> Fallible ()
assertFinalString expected code = do
	result <- finalResult code
	actual <- mapError show $ asNativeString result
	(expected, actual) `isEqualElse`
		"The final evaluated string was unexpected!"

assertFileReturns :: FilePath -> VoidFallible
assertFileReturns path = do
	code <- tryIO $ TextIO.readFile path
	let lines' = Text.lines code
	expectation <- falT $ case lines' of
		firstLine:_ -> case Text.stripPrefix "# returns " firstLine of
			Just expectedCode -> return expectedCode
			Nothing -> Error $
				"The code in " ++ show path ++ " was expected to begin with a # returns line."
		[] ->
			Error $ "The code in " ++ show path ++ " was empty."
	actual <- falT $ finalResult code
	expected <- falT $ finalResult expectation
	falT $ (expected, actual) `isEqualElse`
		("The final evaluated result of " ++ show path ++ " was unexpected.")

assertFileErrors :: FilePath -> VoidFallible
assertFileErrors path = do
	code <- tryIO $ TextIO.readFile path
	falT $ hasErrorElse
		(evaluate code)
		("The code in " ++ show path ++ " was expected to fail when evaluated.")
