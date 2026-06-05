module Beng.Build.TypeTest (
	fromContext,
	satisfiesDuring,
	runTestProgress,
	runTest,
	module Beng.Types.Build.TypeTest
) where

import Utils.Fallible
import Utils.Lists (mapIndexed)
import Utils.Messaging (Messagable, debugM, msg)

import Beng.Build.Context (Context)
import Beng.Types.Build.TypeTest
import Beng.Types.Things (
	Mismatch(..),
	SomeConcreteThing(..),
	SomeParameterizedThing(..),
	SomeThing(..) )
import qualified Beng.Types.Things as Thing

import qualified Data.Map as Map

resolveCandidate :: TypeTest -> SomeThing
resolveCandidate test@TypeTest{current = Contest{candidate}} = do
	case Thing.resolve test.candidateParameterMatches candidate of
		Falue (SomeConcreteThing resolved) -> SomeThing resolved
		Error _ -> SomeThing candidate

resolveRequirement :: TypeTest -> SomeThing
resolveRequirement test@TypeTest{current = Contest{requirement}} = do
	case Thing.resolve test.requirementParameterMatches requirement of
		Falue (SomeConcreteThing resolved) -> SomeThing resolved
		Error _ -> SomeThing requirement

showContestUsing :: Bool -> Contest -> String
showContestUsing useMsg Contest{..} = do
	let show' = if useMsg then msg else show
	let nameOrPlain maybeName value = case maybeName of
		Nothing -> show' value
		Just name -> name ++ " := " ++ show' value
	nameOrPlain candidateName candidate ++ " satisfies? " ++
		nameOrPlain requirementName requirement

showContestMultilineUsing :: String -> Bool -> Contest -> String
showContestMultilineUsing indent useMsg Contest{..} = do
	let show' = if useMsg then msg else show
	let nameOrPlain maybeName value = case maybeName of
		Nothing -> show' value
		Just name -> name ++ " := " ++ show' value
	"\n" ++ indent ++ "Candidate: " ++ nameOrPlain candidateName candidate ++
		"\n" ++ indent ++ "Requirement: " ++ nameOrPlain requirementName requirement

showResolvedContestMultilineUsing :: String -> Bool -> TypeTest -> String
showResolvedContestMultilineUsing indent useMsg test = do
	let show' = if useMsg then msg else show
	let nameOrPlain maybeName value = case maybeName of
		Nothing -> show' value
		Just name -> name ++ " := " ++ show' value
	"\n" ++ indent ++ "Candidate: " ++
		nameOrPlain test.current.candidateName (resolveCandidate test) ++
		"\n" ++ indent ++ "Requirement: " ++
			nameOrPlain test.current.requirementName (resolveRequirement test)

showResolvedTestUsing :: Bool -> TypeTest -> String
showResolvedTestUsing useMsg TypeTest{..} = do
	let showContest contest = showResolvedContestMultilineUsing "\t\t" useMsg
			TypeTest {
				context,
				ongoing,
				current = contest,
				candidateParameterMatches,
				requirementParameterMatches }
	let ongoingTestDesc i contest =
		"\n\tOngoing " ++ show (i+1) ++ ") " ++ showContest contest
	"satisfaction test using " ++ show' context ++ ":\n" ++
		"\tCurrent test) " ++ showContest current ++
		concat (mapIndexed ongoingTestDesc ongoing)
	where show' = if useMsg then msg else show

-- instances

instance Eq Contest where
	(==) c1 c2 = c1.candidate == c2.candidate && c1.requirement == c2.requirement

instance Show Contest where
	show = showContestUsing False

instance Messagable Contest where
	msg = showContestUsing True

instance Eq TypeTest where
	test1 == test2 =
		test1.context == test2.context &&
		test1.ongoing == test2.ongoing &&
		test1.current == test2.current

instance Show TypeTest where
	show = showRawTestUsing False

instance Messagable TypeTest where
	msg = showRawTestUsing True

showRawTestUsing :: Bool -> TypeTest -> String
showRawTestUsing useMsg TypeTest{..} = do
	let showContest contest = showContestMultilineUsing "\t\t" useMsg contest
	let ongoingTestDesc i contest =
		"\n\tOngoing " ++ show (i+1) ++ ") " ++ showContest contest
	let show' = if useMsg then msg else show
	"satisfaction test using " ++ show' context ++ ":\n" ++
		"\tCurrent test) " ++ showContest current ++
		concat (mapIndexed ongoingTestDesc ongoing)

-- exported

fromContext :: Context -> SomeParameterizedThing -> SomeParameterizedThing -> TypeTest
fromContext context candidate requirement = TypeTest {
	context,
	ongoing = [],
	candidateParameterMatches = Map.empty,
	requirementParameterMatches = Map.empty,
	current = Contest {
		candidate = candidate,
		requirement = requirement,
			candidateName = Nothing,
			requirementName = Nothing } }

satisfiesDuring
	:: (TypeTest, SomeParameterizedThing) -> SomeParameterizedThing -> TypeTestProgressResult
satisfiesDuring (test, candidate) requirement = do
	let contest = Contest {
		candidate = candidate,
		requirement = requirement,
		candidateName = Nothing,
		requirementName = Nothing }
	let restoreCaller nextTest = nextTest {
			current = test.current,
			ongoing = test.ongoing }
	if contest == test.current || contest `elem` test.ongoing then do
		debugM $ "UNSATISFIED " ++ showResolvedContestMultilineUsing "\t" True
			test{ current = contest } ++ " due to tautology!"
		Error $ Tautology (SomeThing candidate) (SomeThing requirement)
	else do
		debugM $ "Pushing new contest:" ++ showResolvedContestMultilineUsing "\t" True
			test{ current = contest }
		restoreCaller <$> runTestProgress TypeTest {
			context = test.context,
			ongoing = test.current : test.ongoing,
			candidateParameterMatches = test.candidateParameterMatches,
			requirementParameterMatches = test.requirementParameterMatches,
			current = contest }

runTestProgress :: TypeTest -> TypeTestProgressResult
runTestProgress test = do
	debugM $ "Testing " ++ showResolvedTestUsing True test ++ "..."
	case (test.current.candidate, test.current.requirement) of
		(candidate, requirement) | candidate == requirement -> do
			debugM $ "SATISFIED due to equality: " ++ show candidate ++ " = " ++
				(if show candidate == show requirement then "(identical)" else show requirement)
			Falue test
		(SomeParameterizedThing candidate, SomeParameterizedThing requirement) -> do
			case Thing.satisfiesAsCandidate test candidate (SomeParameterizedThing requirement) of
				Just candidateResult -> case candidateResult of
					Error e -> Error e
					Falue nextTest -> case Thing.asParameter requirement of
						Nothing -> Falue nextTest
						Just _ -> do
							debugM $ "Delegating satisfaction to " ++ show candidate
							(nextTest, SomeThing candidate) `Thing.satisfies` requirement
				Nothing -> do
					debugM $ "Delegating satisfaction to " ++ show candidate
					(test, SomeThing candidate) `Thing.satisfies` requirement

runTest :: TypeTest -> TypeTestResult
runTest = fmap matchesOf . runTestProgress
