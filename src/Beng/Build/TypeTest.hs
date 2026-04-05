module Beng.Build.TypeTest (
	fromContext,
	satisfiesDuring,
	runTest,
	module Beng.Types.Build.TypeTest
) where

import Utils.Fallible
import Utils.Lists (mapIndexed)
import Utils.Messaging (Messagable, debugM, msg)

import Beng.Build.Context (Context)
import Beng.Types.Build.TypeTest
import Beng.Types.Things (Mismatch(..), SomeThing(..))
import qualified Beng.Types.Things as Thing

showContestUsing :: Bool -> Contest -> String
showContestUsing useMsg Contest{..} = do
	let nameOrPlain maybeName value = case maybeName of
		Nothing -> show' value
		Just name -> name ++ " := " ++ show' value
	nameOrPlain candidateName candidate ++ " satisfies? " ++
		nameOrPlain requirementName requirement
	where show' = if useMsg then msg else show

showContestMultilineUsing :: String -> Bool -> Contest -> String
showContestMultilineUsing indent useMsg Contest{..} = do
	let nameOrPlain maybeName value = case maybeName of
		Nothing -> show' value
		Just name -> name ++ " := " ++ show' value
	"\n" ++ indent ++ "Candidate: " ++ nameOrPlain candidateName candidate ++
		"\n" ++ indent ++ "Requirement: " ++ nameOrPlain requirementName requirement
	where show' = if useMsg then msg else show

showTestUsing :: Bool -> TypeTest -> String
showTestUsing useMsg TypeTest{..} = do
	let showContest contest = showContestMultilineUsing "\t\t" useMsg contest
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

deriving instance Eq TypeTest

instance Show TypeTest where
	show = showTestUsing False

instance Messagable TypeTest where
	msg = showTestUsing True

-- exported

fromContext :: Context -> SomeThing -> SomeThing -> TypeTest
fromContext context candidate requirement = TypeTest {
	context,
	ongoing = [],
	current = Contest {
		candidate,
		requirement,
		candidateName = Nothing,
		requirementName = Nothing } }

satisfiesDuring :: (TypeTest, SomeThing) -> SomeThing -> TypeTestResult
satisfiesDuring (test, candidate) requirement = do
	let contest = Contest {
		candidate,
		requirement,
		candidateName = Nothing,
		requirementName = Nothing }
	if contest == test.current || contest `elem` test.ongoing then do
		debugM $ "UNSATISFIED " ++ show contest ++ " due to tautology!"
		Error $ Tautology candidate requirement
	else do
		debugM $ "Pushing new contest:" ++ showContestMultilineUsing "\t" True contest
		runTest TypeTest {
			context = test.context,
			ongoing = test.current : test.ongoing,
			current = contest }

runTest :: TypeTest -> FallibleI Mismatch ()
runTest test = do
	debugM $ "Testing " ++ show test ++ "..."
	case (test.current.candidate, test.current.requirement) of
		(super, sub) | super == sub -> do
			debugM $ "SATISFIED due to equality: " ++ show super ++ " = " ++
				(if show super == show sub then "(identical)" else show sub)
			Falue ()
		(SomeThing super, sub) -> do
			debugM $ "Delegating satisfaction to " ++ show super
			(test, super) `Thing.satisfies` sub
