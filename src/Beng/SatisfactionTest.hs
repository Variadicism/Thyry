module Beng.SatisfactionTest (
	fromContext,
	satisfiesDuring,
	runTest,
	module Beng.Types.SatisfactionTest
) where

import Utils.Fallible
import Utils.Lists (mapIndexed)
import Utils.Messaging (Messagable, debug, debugM, msg)

import Beng.Build.Context (Context)
import qualified Beng.Build.Context as C
import Beng.Ops.Declarations (isReturnTypeMismatch)
import Beng.Types.Build.Cards (Card(..))
import Beng.Types.SatisfactionTest
import qualified Beng.Types.SatisfactionTest as ST
import Beng.Types.Things (Mismatch(..), Thing(..))

import Control.Monad (void)
import Data.List (intercalate)
import Data.Map ((!?))
import qualified Data.Map as Map
import qualified Data.Set as Set

-- private

satisfiesProps :: (SatisfactionTest, Thing) -> (Thing -> [Card]) -> FallibleI Mismatch ()
satisfiesProps (test, super) propsWith = do
	let checkProp prop = do
		debugM $ "Testing satisfaction of prop: " ++ show prop ++ "..."

		let propTest :: SatisfactionTest = case prop of
			DefCard _ -> do
				-- Definitions can only fail if one of the other props obscures them.
				let propsContext = C.fromThings [test.current.super]
				debug ("Restricing test context to props for definition prop: " ++ show propsContext)
					test{ ST.context = propsContext }
			DecCard _ -> test

		void $ case (prop, propTest `C.has` prop.declaration) of
			(_, Falue _) -> do
				debugM $ "SATISFIED prop: " ++ show prop
				Falue ()
			{- The satisfaction check is only necessary for definition props at all in case a card
				satisfies the pattern, but not the return type, which would obscure the prop needed.
				(Any attempt to call the prop needed would instead call the card with the wrong type.) -}
			-- TODO: what if the prop is partially obscured?
			(prop, Error e) | isReturnTypeMismatch e -> do
				let obscureError = ObscuredProperty prop e
				debugM $ "UNSATISFIED prop due to obscuring: " ++ show obscureError
				Error obscureError
			{- Pattern mismatches are okay on definition props (but not declaration props) because the
				definition prop can be satisfied by the prop itself (since it has a definition). -}
			(DefCard _, Error _) -> do
				debugM $ "SATISFIED definition prop by itself (no match in context, " ++
					"but no obscuring card): " ++ show prop
				Falue ()
			(DecCard decProp, Error e) -> do
				let unsatisfiedError = UnsatisfiedProperty decProp e
				debugM $ "UNSATISFIED declaration prop: " ++ show unsatisfiedError
				Error unsatisfiedError

	{- Fill sub's properties with super because super only needs to satisfy cards
	   with its own type, not _all_ of the sub's type, e.g., if number declares
	   'one' + 'one' as a property, int only needs to define 'int' + 'int' to satisfy
	   number's type, not 'number' + 'number'. -}
	void $ sequence $ map checkProp $ propsWith super

showContestUsing :: Bool -> Contest -> String
showContestUsing useMsg Contest{..} = do
	let nameOrPlain maybeName value = case maybeName of
		Nothing -> show' value
		Just name -> name ++ " := " ++ show' value
	nameOrPlain superName super ++ " satisfies? " ++ nameOrPlain subName sub
	where show' = if useMsg then msg else show

showContestMultilineUsing :: String -> Bool -> Contest -> String
showContestMultilineUsing indent useMsg Contest{..} = do
	let nameOrPlain maybeName value = case maybeName of
		Nothing -> show' value
		Just name -> name ++ " := " ++ show' value
	"\n" ++ indent ++ "Super: " ++ nameOrPlain superName super ++
		"\n" ++ indent ++ "Sub: " ++ nameOrPlain subName sub
	where show' = if useMsg then msg else show

showTestUsing :: Bool -> SatisfactionTest -> String
showTestUsing useMsg SatisfactionTest{..} = do
	let showContest contest = showContestMultilineUsing "\t\t" useMsg contest
	let ongoingTestDesc i contest =
		"\n\tOngoing " ++ show (i+1) ++ ") " ++ showContest contest
	"satisfaction test using " ++ show' context ++ ":\n" ++
		"\tCurrent test) " ++ showContest current ++
		concat (mapIndexed ongoingTestDesc ongoing)
	where show' = if useMsg then msg else show

-- instances

instance Eq Contest where
	(==) c1 c2 = c1.super == c2.super && c1.sub == c2.sub

instance Show Contest where
	show = showContestUsing False

instance Messagable Contest where
	msg = showContestUsing True

deriving instance Eq SatisfactionTest

instance Show SatisfactionTest where
	show = showTestUsing False

instance Messagable SatisfactionTest where
	msg = showTestUsing True

-- exported

fromContext :: Context -> Thing -> Thing -> SatisfactionTest
fromContext context super sub = SatisfactionTest {
	context,
	ongoing = [],
	current = Contest { super, sub, superName = Nothing, subName = Nothing } }

satisfiesDuring :: (SatisfactionTest, Thing) -> Thing -> SatisfactionTestResult
satisfiesDuring (test, super) sub = do
	let contest = Contest { super, sub, superName = Nothing, subName = Nothing }
	if contest == test.current || contest `elem` test.ongoing then do
		debugM $ "UNSATISFIED " ++ show contest ++ " due to tautology!"
		Error $ Tautology super sub
	else do
		debugM $ "Pushing new contest:" ++ showContestMultilineUsing "\t" True contest
		runTest SatisfactionTest {
			context = test.context,
			ongoing = test.current : test.ongoing,
			current = contest }

runTest :: SatisfactionTest -> FallibleI Mismatch ()
runTest test = do
	debugM $ "Testing " ++ show test ++ "..."

	let testBits superSize subSize super sub =
		if superSize <= subSize then do
			debugM $ "SATISFIED because " ++ show superSize ++
				" bits can be padded to " ++ show subSize ++ " bits"
			Falue ()
		else do
			debugM $ "UNSATISFIED because " ++ show superSize ++
				" is too few bits (needed " ++ show subSize ++ ")"
			Error $ PrimitiveMismatch super sub
	-- runTest' avoids excess test info debug spam.
	let runTest' test = do
		let testListLike super sub supers subs =
			if length supers < length subs then do
				debugM $ "UNSATISFIED list-likes because " ++ show (length supers) ++
					" is too few elements (needed " ++ show (length subs) ++ ")"
				Error $ PrimitiveMismatch super sub
			else do
				let elementSatisfied superElement subElement =
					(test, superElement) `satisfiesDuring` subElement
				void $ sequence $ zipWith elementSatisfied supers subs
		let testListLikeType elementType values =
			void $ sequence $ map (\v -> (test, v) `satisfiesDuring` elementType) values
		case (test.current.super, test.current.sub) of
			-- congruent types
			(super, sub) | super == sub -> do
				debugM $ "SATISFIED due to equality: " ++ show super ++ " = " ++
					(if show super == show sub then "(identical)" else show sub)
				Falue ()
			(super@NativeBitsType{}, sub@NativeBitsType{}) ->
				testBits super.size sub.size super sub
			(super@OpType{}, sub@OpType{}) -> do
				debugM $ "Testing ops' return types..."
				(test, super.returnType) `satisfiesDuring` sub.returnType
				debugM $ "Ops' return types match; testing ops' arguments..."
				let argKeys = Set.union (Set.fromList $ Map.keys sub.args) (Set.fromList $ Map.keys super.args)
				let checkArgs key = case (super.args !? key, sub.args !? key) of
					(Nothing, Nothing) ->
						error $ "Impossible: there was no '" ++ key ++ "' arg in either " ++ show super ++
							" or " ++ show sub ++ "!"
					(Just superArgType, Nothing) -> Error $ ExtraArgument key superArgType sub.args
					(Nothing, Just subArgType) -> Error $ MissingArgument key subArgType super.args
					(Just superArgType, Just subArgType) ->
						mapError (MismatchedArgument key superArgType subArgType) $
							(test, subArgType) `satisfiesDuring` superArgType
				void $ sequence $ map checkArgs $ Set.elems argKeys
				debugM "SATISFIED op type"
			(super@NativeListType{}, sub@NativeListType{}) ->
				(test, super.elementType) `satisfiesDuring` sub.elementType
			(super@NativeSomeType{}, sub@NativeSomeType{}) ->
				(test, super.elementType) `satisfiesDuring` sub.elementType
			(super@NativeOptionalType{}, sub@NativeOptionalType{}) ->
				(test, super.falueType) `satisfiesDuring` sub.falueType
			-- values
			(super@NativeListValue{}, sub@NativeListValue{}) ->
				testListLike super sub super.values sub.values
			(super@NativeSomeValue{}, sub@NativeSomeValue{}) ->
				testListLike super sub super.valuesP.l sub.valuesP.l
			-- types and values
			(super@NativeBitsType{}, sub@NativeBitsValue{}) ->
				testBits super.size sub.size super sub
			(NativeCharType, NativeCharValue{}) -> Falue ()
			(NativeStringType, NativeStringValue{}) -> Falue ()
			(super@NativeListType{}, sub@NativeListValue{}) ->
				testListLikeType super.elementType sub.values
			(super@NativeSomeType{}, sub@NativeSomeValue{}) ->
				testListLikeType super.elementType sub.valuesP.l
			(super@NativeOptionalType{}, sub@NativeOptionalValue{}) -> case sub.fal of
				Error _ -> Falue ()
				Falue v -> (test, v) `satisfiesDuring` super.falueType
			-- disparate types
			(super, sub@NativeType{}) ->
				(test, super) `satisfiesProps` sub.properties
			(super@CombinedThings{}, sub) -> do
				debugM $ "Deconstructing compound super value: " ++ intercalate " AND " (map msg super.things.l)
				void $ sequenceAny $ map (\v -> (test, v) `satisfiesDuring` sub) super.things.l
			(super, sub@CombinedThings{}) -> do
				debugM $ "Deconstructing compound sub value: " ++ intercalate " AND " (map show sub.things.l)
				void $ sequence $ map ((test, super) `satisfiesDuring`) sub.things.l
			(super@NamedThing{..}, _) -> do
				debugM $ "Deconstructing named super value: \"" ++ name ++ "\""
				runTest' test{ ST.current = test.current{ super = super.value, superName = Just name }}
			(_, sub@NamedThing{..}) -> do
				debugM $ "Deconstructing named sub value: \"" ++ name ++ "\""
				runTest' test{ ST.current = test.current{ sub = sub.value, subName = Just name }}
			-- TODO: when native types satisfy language-level types: (super@NativeType{}, sub)
			(super@NativeListType{}, sub@NativeSomeType{}) ->
				(test, super.elementType) `satisfiesDuring` sub.elementType
			-- NativeSomeType cannot satisfy NativeListType becauses lists can be empty!
			(super@NativeListType{}, sub@NativeSomeValue{}) ->
				testListLikeType super.elementType sub.valuesP.l
			(super@NativeListValue{}, sub@NativeSomeValue{}) ->
				testListLike super sub super.values sub.valuesP.l
			(super@NativeSomeValue{}, sub@NativeListValue{}) ->
				testListLike super sub super.valuesP.l sub.values 
			(super@NativeOptionalType{}, sub) -> do
				debugM $ "Deconstructing optional super value: " ++ show super.falueType
				(test, super.falueType) `satisfiesDuring` sub
			(super, sub@NativeOrType{}) -> void $
				sequence $ map (\subOption -> (test, subOption) `satisfiesDuring` super) sub.options.l
			(super@NativeOrType{}, sub) ->
				void $ sequenceAny $ map ((test, sub) `satisfiesDuring`) super.options.l
			(super, sub) -> do
				debugM $ "UNSATISFIED " ++ show sub ++ " by " ++ show super ++
					" via incongruence or unequal values"
				Error $ PrimitiveMismatch super sub
	runTest' test