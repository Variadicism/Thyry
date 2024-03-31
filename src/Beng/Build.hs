{- "Building" in Beng may seem similar to parsing, but there is more to it:
   building also includes evaluating the bodies of Ops to find the contexts
   they build, which will be used to parse the PreOps they take in.
   Parsing and running must intertwine for this to work. -}

module Beng.Build (
	buildCodeUsing,
	buildCode,
	buildFile
) where

import Utils.Fallible hiding (Fallible)
import Utils.Fallible.Trans
import Utils.Lists (wrap)
import Utils.Messaging (debug, debugM)
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Strings (parenthesize)

import qualified Beng.Build.Context.Builtin as Builtin
import qualified Beng.Build.Ops as Op
import Beng.Build.Types.Context (Context)
import Beng.Errors (printError)
import Beng.Parse.Parsers ((@+>), (<<<), (>:>), (>\>), Parse(..), Parses(..), State(..), fileStartState, parseWhile)
import qualified Beng.Parse.Patterns.Space as Space
import Beng.Ops.Types (Op)

import Control.Monad (when)
import Data.Char (isSpace)
import Data.List (intercalate)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text
import qualified Data.Text.Lazy.IO as Text
import System.IO (IOMode(ReadMode), openFile)

-- exports

buildCodeUsing :: Context -> FilePath -> Text -> FallibleI String (Populace Op)
buildCodeUsing context filePath code = do
	let initialState = fileStartState filePath context code

	let hasText = \state ->
		debug (wrap "\n" $ "Done parsing op; parsing " ++
				show (Text.length state.rest) ++ " characters remaining in " ++
				filePath ++ " at " ++ show state ++ "...") $
			Text.any (not . isSpace) state.rest
	let parser = "build code in " ++ filePath @+>
		parseWhile "text remains" hasText (Space.parse >:> Op.build filePath >\> snd)

	Parses{parses} <- mapError printError (parser <<< initialState)

	let opsLists :: Populace [Op] = P.map target parses
	let assertOpsPresent = flip P.assert "Is it just me or is there no code in here?"
	opPopuli <- P.sequenceAny $ P.map assertOpsPresent opsLists

	when (not $ null $ opPopuli.tail) $ debugM $
		"This Beng code is ambiguous! " ++
		show (length opPopuli) ++ " ways were found to parse it:\n" ++
		(intercalate (wrap "\n" $ replicate 20 '#') $
			map (intercalate "\n" . map (parenthesize . show) . P.toList) opPopuli.l)

	return opPopuli.head

buildCode :: (FilePath -> Text -> FallibleI String (Populace Op))
buildCode = buildCodeUsing Builtin.context

buildFile :: FilePath -> IOFallible (Populace Op)
buildFile path = do
	file <- tryIO $ openFile path ReadMode
	code <- tryIO $ Text.hGetContents file
	falT $ buildCode path code