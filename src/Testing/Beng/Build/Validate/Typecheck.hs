module Testing.Beng.Build.Validate.Typecheck (
	testTypecheck
) where

import Utils.Fallible (mapError)
import Utils.Messaging (msg)
import qualified Utils.Populace.Populace2 as P2
import Utils.Testing

import qualified Beng.Build.Context as Context
import Beng.Build.Context.Builders (argOfBuiltin, bitType, bitValue, declare, define, intType, intValue, l, s)
import Beng.Things (Thing(..), satisfies, thing)
import Beng.Types.Build.Cards (Card(..))
import Beng.Types.Build.Context (PrecedenceBound(..))
import Beng.Types.Locations (Location(..))

-- tests

testTypecheck :: TestCategory
testTypecheck = TestCategories "typecheck" do
	{- Beng equivalent:
		\a sound := a native string
		
		\an animal := \yell as 'one' => a sound :/=

		# Satisfies animal easily by props alone
		\a dog := an animal +
			\yell as 'one' := "bark"
			\fetch 'Thing' as 'Dog' => thing :/=

		# Satisfies yell, but not as a property, so it should still be an animal in context
		\a cat := an animal +
			\kill 'Animal' as 'Cat' => animal :/=
		\yell as 'cat' := "yowl"

		\a human := an animal +
			\yell as 'one' := "shout"
			\Birth Year of 'one' => an int :/=
			\'one' has a good portrait := yes
			\Philosophy of 'one' => a native string := "To be or not to be?"

		# Does not include human in the formula, but still satisfies all properties.
		\Paris Hilton :=
			\yell as 'one' := "shout"
			\Birth Year of 'one' := 1981
			\'one' has a good portrait := yes
			\Philosophy of 'one' := "Life is too short to blend in."

		# Satisfies the necessary Birth Year, but leaves yell and good portrait to defaults
		\Rene Descartes := a human +
			\Birth Year of 'one' := 1596
			\Philosophy of 'one' := "I think, therefore I am."

		# Does not include human in the formula, but satisfies all properties except
		# "philosophize...", but that has a default implementation, so he is still considered a human.
		\William Shakespeare :=
			\yell as 'one' := "shout"
			\Birth Year of 'one' := 1564
			\'one' has a good portrait := yes

		# Has all props of a human, but does not satisfy "good portrait" by return type; NOT human!
		\Bigfoot :=
			\yell as 'one' := "shout"
			\Birth Year of 'one' := 1811
			\'one' has a good portrait := no
			\Philosophy of 'one' := "MAKE OWN PATH THRU FOREST"
	-}

	let a = argOfBuiltin

	let decForProp parentIndex propIndex subpatternsFor returnType one =
		declare Default (subpatternsFor one) returnType
			BuiltinProp { parentIndex, propIndex, one }
	let defForOp index subpatternsFor returnType run one =
		define Default (subpatternsFor one) returnType run Builtin { index }
	let defForProp parentIndex propIndex subpatternsFor returnType run one =
		define Default (subpatternsFor one) returnType run
			BuiltinProp { parentIndex, propIndex, one }
	let defConstantForOp index subpatternsFor result =
		defForOp index subpatternsFor result (const $ return result)
	let defNamedForOp index literal result =
		-- One is unused because there are no arguments in the subpatterns.
		defConstantForOp index (const [l literal]) result One
	let defConstantForProp parentIndex propIndex subpatternsFor result =
		defForProp parentIndex propIndex subpatternsFor result (const $ return result)

	let sound = NamedThing "a sound" NativeStringType

	let yellSubpatternsFor i one = [l "yell", s, l "as", s, a i "One" one]
	let declareYellPropFor i j = decForProp i j (yellSubpatternsFor i) sound
	let defineYellForOp i result =
		defConstantForOp i (yellSubpatternsFor i) (NativeStringValue result)
	let defineYellForProp i j result =
		defConstantForProp i j (yellSubpatternsFor i) (NativeStringValue result)
	
	let animal = NamedThing "an animal" $ NativeType
		\one -> [DecCard $ declareYellPropFor 0 0 one]
	let animalDef = DefinitionValue $ defNamedForOp 0 "an animal" animal

	let killSubpatternsFor i one =
		[l "kill", s, a i "Animal" animal, s, l "as", s, a i "One" one]
	let declareKillFor i j = decForProp i j (killSubpatternsFor i) animal

	let cat = NamedThing "a cat" $ CombinedThings $ P2.dualton
		animal $
		NativeType \one -> [DecCard $ declareKillFor 1 0 one]
	let catDef = DefinitionValue $ defNamedForOp 1 "a cat" cat
	let yowlDef = DefinitionValue $ defineYellForOp 2 "yowl" cat

	let fetchSubpatternsFor i one =
		[l "fetch", s, a i "Thing" thing, s, l "as", s, a i "One" one]
	let declareFetchForProp i j = decForProp i j (fetchSubpatternsFor i) thing

	let dog = NamedThing "a dog" $ CombinedThings $ P2.dualton
		animal $
		NativeType \one -> [
			DecCard $ declareFetchForProp 3 0 one,
			DefCard $ defineYellForProp 3 1 "bark" one]
	let dogDef = DefinitionValue $ defNamedForOp 3 "a dog" dog

	let birthYearSubpatternsFor i one = [l "Birth Year for ", a i "One" one]
	let declareBirthYearFor i j = decForProp i j (birthYearSubpatternsFor i) intType
	let defineBirthYearFor i j result =
		defConstantForProp i j (birthYearSubpatternsFor i) (intValue result)

	let goodPortraitSubpatternsFor i one = [a i "One" one, l " has a good portrait"]
	let defineGoodPortraitFor i j result =
		defConstantForProp i j (goodPortraitSubpatternsFor i) (bitValue result)

	let philosophizeSubpatternsFor i one = [l "philosophize", s, l "as", s, a i "One" one]
	let definePhilosophizeFor i j result =
		defConstantForProp i j (philosophizeSubpatternsFor i) (NativeStringValue result)

	let human = NamedThing "a human" $ CombinedThings $ P2.dualton
		animal $
		NativeType \one -> [
			DefCard $ defineYellForProp 4 0 "shout" one,
			DecCard $ declareBirthYearFor 4 1 one,
			DefCard $ defineGoodPortraitFor 4 2 True one,
			DefCard $ defForProp 4 3 (philosophizeSubpatternsFor 4) NativeStringType
				(const $ return $ NativeStringValue "To be or not to be?") one]
	let humanDef = DefinitionValue $ defNamedForOp 4 "a human" human

	let parisHilton = NamedThing "Paris Hilton" $ NativeType \one -> [
		DefCard $ defineYellForProp 5 0 "shout" one,
		DefCard $ defineBirthYearFor 5 1 1981 one,
		DefCard $ defineGoodPortraitFor 5 2 True one,
		DefCard $ definePhilosophizeFor 5 3 "Life is too short to blend in." one]
	let parisHiltonDef = DefinitionValue $ defNamedForOp 5 "Paris Hilton" parisHilton

	let reneDescartes = NamedThing "Rene Descartes" $ CombinedThings $ P2.dualton
		human $
		NativeType \one -> [
			DefCard $ defineBirthYearFor 6 0 1596 one,
			DefCard $ definePhilosophizeFor 6 1 "I think, there I am." one]
	let reneDescartesDef = DefinitionValue $ defNamedForOp 6 "Rene Descartes" reneDescartes

	let williamShakespeare = NamedThing "William Shakespeare" $ NativeType \one -> [
		DefCard $ defineYellForProp 7 0 "shout" one,
		DefCard $ defineBirthYearFor 7 1 1564 one,
		DefCard $ defineGoodPortraitFor 7 2 True one]
	let williamShakespeareDef = DefinitionValue $
		defNamedForOp 7 "William Shakespeare" williamShakespeare

	let bigfoot = NamedThing "Bigfoot" $ NativeType \one -> [
		DefCard $ defineYellForProp 8 0 "shout" one,
		DefCard $ defineBirthYearFor 8 1 1811 one,
		DefCard $ defineGoodPortraitFor 8 2 False one,
		DefCard $ definePhilosophizeFor 8 3 "MAKE OWN PATH THRU FOREST" one]
	let bigfootDef = DefinitionValue $ defNamedForOp 8 "Bigfoot" bigfoot

	let votedSubpatternsFor i one = [a i "One" one, l " voted this year"]
	let declareVotedFor i j = decForProp i j (votedSubpatternsFor i) bitType

	let milleniumBaby = NamedThing "a millenium baby" $ CombinedThings $ P2.dualton
		human $
		NativeType \one -> [
			DefCard $ defineBirthYearFor 9 0 2000 one,
			DecCard $ declareVotedFor 9 1 one]
	let milleniumBabyDef = DefinitionValue $ defNamedForOp 9 "a millenium baby" milleniumBaby

	{- Note that the way this context is assembled is not necessarily the way context is really handled;
		most notably, the properties of a thing should always be treated as the top of the context stack
		wherever the thing is used as an argument, but here, all the properties are flattened. -}
	let context = Context.fromThings [
		animalDef,
		animal,
		catDef,
		cat,
		yowlDef,
		dogDef,
		dog,
		humanDef,
		human,
		parisHiltonDef,
		parisHilton,
		reneDescartesDef,
		reneDescartes,
		williamShakespeareDef,
		williamShakespeare,
		bigfootDef,
		bigfoot,
		milleniumBabyDef,
		milleniumBaby ]

	let assertSatisfies super sub = mapError msg $ (context, super) `satisfies` sub
	let assertDoesNotSatisfy super sub =
		assertSatisfies super sub `hasErrorElse` "This should not have been satisfied!"

	[
		PureTests "equal" [
			("native basic", sound `assertSatisfies` sound),
			("native constructed type", cat `assertSatisfies` cat),
			("thing value", reneDescartes `assertSatisfies` reneDescartes) ],
		PureTests "satisfies by props" [
			("human is an animal", human `assertSatisfies` animal),
			("Rene is a human", reneDescartes `assertSatisfies` human),
			("a millenium baby is a human", milleniumBaby `assertSatisfies` human) ],
		PureTests "satisfies by context" [
			("cat is an animal", cat `assertSatisfies` animal),
			("Paris Hilton is a human", parisHilton `assertSatisfies` human),
			("William Shakespeare is a human", williamShakespeare `assertSatisfies` human) ],
		PureTests "does not satisfy" [
			("Rene is not a sound", reneDescartes `assertDoesNotSatisfy` sound),
			("Rene is not a cat", reneDescartes `assertDoesNotSatisfy` cat),
			("William Shakespeare is not a dog", williamShakespeare `assertDoesNotSatisfy` dog),
			("Bigfoot is not a human", bigfoot `assertDoesNotSatisfy` human),
			("Paris is not a millenium baby", parisHilton `assertDoesNotSatisfy` milleniumBaby) ]]
