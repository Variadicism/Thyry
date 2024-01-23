module Beng.Build.Context.Builtin (
	context
) where

import Prelude hiding (subtract)

import Beng.Build.Context (Context(..), PrecedenceBound(..))
import Beng.Build.Context.Builders (a, c, cr, e, s, l, t, multi, asOp, buildContextFrom, declarationOf, define, defineUsing, defineLiteral, definitionOf)
import Beng.Build.Types.Cards (Card(DefCard))
import Beng.Parse.Types.Matches (Capture(..))
import Beng.Parse.Types.Patterns (Pattern(..))
import Beng.Run.Ops (run)
import Beng.Types.Ops.Declarations (Associativity(..), Declaration)
import Beng.Types.Ops.Definitions (Definition(..))
import Beng.Types.Locations (Location)

import Data.Map ((!))
import Data.Text.Lazy (unpack)
import GHC.Records (HasField, getField)

-- constants

valueName :: Pattern
valueName = do
	let uppercaseLetter = c [cr 'A' 'Z'] []
	let letter = c [cr 'A' 'Z', cr 'a' 'z'] []
	let capitalizedWord = And [uppercaseLetter, Or [e, multi letter]]
	Delimited { delimiter = Space, delimitend = capitalizedWord }

-- builtin enumeration

{- This enum-based system is used to allow definitions to be referenced while building the
   context despite the fact that they receive their Location when the Context is built.
   The location of Builtin ops is simply derived from their index in the Context, so by
   relating the definitions to an enum and pushing the definitions into the Context
   in Enum order when we build it, we can know the index of each Definition early.

   Yes, it's extremely inconvenient and if Haskell had more advanced Enum structures like
   Java or Beng, this wouldn't be such a pain. -}

data BuiltinOp =
	Integers |
	Add | Subtract |
	DefineValue
	deriving (Show, Eq, Enum, Ord)

instance HasField "definition" BuiltinOp Definition where
	getField = definitionOf hangingDefinitionOf

instance HasField "declaration" BuiltinOp Declaration where
	getField = declarationOf hangingDefinitionOf

hangingDefinitionOf :: (BuiltinOp -> Location -> Definition)
hangingDefinitionOf = \case
	-- Types of the arguments and the values in these definitions are disjointed,
	-- losing all type guarantees. This will not be an issue in Beng! :)
	Integers -> define None
		[t "Integer" $ multi $ c [cr '0' '9'] []]
		\args -> do
			let (StringCapture text) = args ! "Integer"
			-- `read :: Int` is safe because we only match '0'-'9'.
			return (read $ unpack text :: Int)
	Add -> define Default
		[a "Augend", s, l "+", s, a "Addend"]
		\args -> do
			augend <- run $ asOp $ args ! "Augend"
			addend <- run $ asOp $ args ! "Addend"
			return $ augend + addend
	Subtract -> define (At $ dec Add)
		[a "Minuend", s, l "-", s, a "Subtrahend"]
		\args -> do
			minuend <- run $ asOp $ args ! "Minuend"
			subtrahend <- run $ asOp $ args ! "Subtrahend"
			return $ minuend - subtrahend
	DefineValue -> defineUsing (Below $ dec Add) Righty
		[t "Name" valueName, s, l ":=", s, a "Value", s, a "Scope"]
		(\name args location -> return case name of
			"Scope" -> do
				let (StringCapture name) = args ! "Name"
				[DefCard $ defineLiteral name (asOp $ args ! "Value") location]
			_ -> [])
		\args -> run $ asOp $ args ! "Scope"
	where dec = declarationOf hangingDefinitionOf

-- exported

context :: Context
context = buildContextFrom hangingDefinitionOf Integers