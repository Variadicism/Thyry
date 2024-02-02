{- "Building" in Beng may seem similar to parsing, but there is more to it:
   building also includes evaluating the bodies of Ops to find the contexts
   they build, which will be used to parse the PreOps they take in.
   Parsing and running must intertwine for this to work. -}

module Beng.Build (
	buildCodeUsing,
	buildCode,
	buildFile
) where

import Utils.Fallible
import Utils.Fallible.Trans
import Utils.Lists (wrap)
import Utils.Messaging (debugM)
import Utils.Populace (Populace)
import qualified Utils.Populace as P
import Utils.Strings (parenthesize)

import qualified Beng.Build.Context.Builtin as Builtin
import qualified Beng.Build.Ops as Op
import Beng.Build.Types.Context (Context)
import Beng.Errors (printError)
import Beng.Parse.Parsers ((@>), (<<<), (>>>), (>:>), (>\>), Parse(..), ParseRunner, Results, State(..), fileStartState, takeAs)
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

-- Unlike much of this program, this module uses the traditional Fallibles with String-type errors.

buildCodeUsing :: Context -> FilePath -> Text -> Fallible (Populace Op)
buildCodeUsing context filePath code = do
	let initialState = fileStartState filePath context code

	let parser = "build code" @> do
		let parseOpsIfText :: ParseRunner [Op] = \state ->
			if Text.null state.rest then
				takeAs "" [] state
			else do
				let falOpResults = state >>> Space.parse >:> Op.build filePath >\> snd
				if hasError falOpResults && Text.all isSpace state.rest then
					takeAs "" [] state
				else do
					opResults <- falOpResults
					let prependOpAndContinue :: Parse Op -> Results [Op] = \opParse -> do
						debugM $ wrap "\n" $ "Done parsing op from " ++ show filePath ++
							"; parsing " ++ show (Text.length state.rest) ++
							" characters remaining in " ++ filePath ++ "..."
						tailResults <- parseOpsIfText opParse.state
						let prependOp :: Parse [Op] -> Parse [Op] = \tailParse ->
							tailParse{ target = opParse.target : tailParse.target }
						return $ P.map prependOp tailResults

					let continuedResults :: Populace (Results [Op]) =
						P.map prependOpAndContinue opResults
					fullResults <- P.sequenceAny continuedResults
					return $ P.concat fullResults
		parseOpsIfText

	let resultsOrBengError = parser <<< initialState
	results <- mapError printError resultsOrBengError

	let opsLists :: Populace [Op] = P.map target results
	let assertOpsPresent = flip P.assert "Is it just me or is there no code in here?"
	opPopuli <- P.sequenceAny $ P.map assertOpsPresent opsLists

	when (not $ null $ opPopuli.tail) $ debugM $
		"This Beng code is ambiguous! " ++
		show (length opPopuli) ++ " ways were found to parse it:\n" ++
		(intercalate (wrap "\n" $ replicate 20 '#') $
			map (intercalate "\n" . map (parenthesize . show) . P.toList) opPopuli.l)

	return opPopuli.head

buildCode :: (FilePath -> Text -> Fallible (Populace Op))
buildCode = buildCodeUsing Builtin.context

buildFile :: FilePath -> IOFallible (Populace Op)
buildFile path = do
	file <- tryIO $ openFile path ReadMode
	code <- tryIO $ Text.hGetContents file
	falT $ buildCode path code