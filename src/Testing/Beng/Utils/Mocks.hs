module Testing.Beng.Utils.Mocks (
	mockNothing,
	aValue,
	bValue,
	a,
	b,
	divide,
	mockABDivision
) where

import Prelude hiding ((<), (>))

import Beng.Build.Context.Builders ((=~), s, l, define, defineLiteral)
import Beng.Build.Types.Context (Context(..))
import Beng.Types.Ops.Definitions (Definition)
import Beng.Run.Types.Values (Value(..), ValueType(..))

import Data.Map ((!))
import qualified Data.Set as Set

-- constants

mockNothing = Context {
	precedence = [],
	definitions = [] }

aValue :: Int
aValue = 3

bValue :: Int
bValue = 7

a :: Definition
a = defineLiteral "a" $ IntValue aValue

b :: Definition
b = defineLiteral "b" $ IntValue bValue

divide :: Definition
divide = define
	["Dividend" =~ IntType, s, l "/", s, "Divisor" =~ IntType]
	\args -> do
		let (IntValue dividend) = args ! "Dividend"
		let (IntValue divisor) = args ! "Divisor"
		IntValue $ dividend `div` divisor 

mockABDivision = Context {
	precedence = [Set.singleton 0],
	definitions = [a, b, divide] }