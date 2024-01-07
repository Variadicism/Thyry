module Beng.Parse (
	parseCode,
	parseFile
) where

import Utils.Errors (Fallible, toError)
import Utils.Lists (wrap)
import Utils.Messaging (debugM)
import Utils.Monads (IOFallible, falT, tryIO)

import Beng.Ops (Op)
import qualified Beng.Ops as Op
import Beng.Ops.Builtin (builtinContext)
import qualified Beng.Parse.Ops as Op
import Beng.Parse.Parsers ((<<<), Result(..), SpaceState(Space), State(..), parseWhile)

import Data.List (intercalate)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text
import qualified Data.Text.Lazy.IO as Text
import System.IO (IOMode(ReadMode), openFile)

-- exports

parseCode :: String -> Text -> Fallible [Op]
parseCode contextDescription rawCode = do
	-- TODO: remove this when extraneous whitespace can be allowed anywhere.
	let code = if "\n" `Text.isSuffixOf` rawCode
		then Text.dropEnd 1 rawCode
		else rawCode
	let initialState = State {
		context = builtinContext,
		spaceState = Space,
		rest = code }
	let results = parseWhile (Op.parse contextDescription) <<< initialState
	let completeResults = map target $ filter (Text.null . rest . state) results
	-- TODO: include last state information in errors
	case completeResults of
		[] -> toError "There was a problem parsing this Beng code!"
		[onlyRead] -> return onlyRead
		readPossibilities@(firstPossibility:(_:_)) -> do
			debugM ("This Beng code is ambiguous! " ++
				show (length readPossibilities) ++ " ways were found to parse it:\n" ++
				(intercalate (wrap "\n" $ replicate 20 '#') $
					map (intercalate "\n" . map Op.showParens) readPossibilities))
			return firstPossibility

parseFile :: FilePath -> IOFallible [Op]
parseFile path = do
	file <- tryIO $ openFile path ReadMode
	code <- tryIO $ Text.hGetContents file
	falT $ parseCode path code