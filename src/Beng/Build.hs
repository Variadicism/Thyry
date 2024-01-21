{- "Building" in Beng may seem similar to parsing, but there is more to it:
   building also includes evaluating the bodies of Ops to find the contexts
   they build, which will be used to parse the PreOps they take in.
   Parsing and running must intertwine for this to work. -}

module Beng.Build (
	buildCodeUsing,
	buildCode,
	buildFile
) where

import Utils.Errors (Fallible, toError)
import Utils.Lists (wrap)
import Utils.Messaging (debugM)
import Utils.Monads (IOFallible, falT, tryIO)
import Utils.Strings (parenthesize)

import qualified Beng.Build.Context.Builtin as Builtin
import qualified Beng.Build.Ops as Op
import Beng.Build.Types.Context (Context)
import Beng.Parse.Parsers ((<<<), (>:>), (>\>), Result(..), State(..), fileStartState, parseWhile)
import qualified Beng.Parse.Patterns.Space as Space
import Beng.Types.Ops (Op)

import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (intercalate)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text
import qualified Data.Text.Lazy.IO as Text
import System.IO (IOMode(ReadMode), openFile)

-- exports

buildCodeUsing :: Context -> String -> Text -> Fallible [Op]
buildCodeUsing context contextDescription code = do
	when (Text.all isSpace code) $ toError $
		"Did-- did you really ask me to compile code that's all whitespace?\n" ++
		"This isn't Whitespace lang."
	let initialState = fileStartState context code
	let opParser = Op.build contextDescription
	let parser = Space.parse >:> opParser >\> snd
	let results = parseWhile parser <<< initialState
	let completeResults = map target $ filter (Text.all isSpace . rest . state) results
	-- TODO: include last state information in errors
	case completeResults of
		[] -> toError "There was a problem parsing this Beng code!"
		[onlyRead] -> return onlyRead
		readPossibilities@(firstPossibility:(_:_)) -> do
			debugM ("This Beng code is ambiguous! " ++
				show (length readPossibilities) ++ " ways were found to parse it:\n" ++
				(intercalate (wrap "\n" $ replicate 20 '#') $
					map (intercalate "\n" . map (parenthesize . show)) readPossibilities))
			return firstPossibility

buildCode :: (String -> Text -> Fallible [Op])
buildCode = buildCodeUsing Builtin.context

buildFile :: FilePath -> IOFallible [Op]
buildFile path = do
	file <- tryIO $ openFile path ReadMode
	code <- tryIO $ Text.hGetContents file
	falT $ buildCode path code