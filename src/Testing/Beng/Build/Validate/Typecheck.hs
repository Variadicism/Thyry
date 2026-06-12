module Testing.Beng.Build.Validate.Typecheck (
	testTypecheck
) where

import Utils.Fallible (mapError)
import Utils.Messaging (msg)
import qualified Utils.Populace.Populace2 as P2
import Utils.Testing

import qualified Beng.Build.Context as Context
import Beng.Types.Operators (SomeOperator(..))
import Beng.Build.Context.Builders (
	argOfBuiltin,
	bitType,
	bitValue,
	declare,
	define,
	intType,
	intValue,
	l,
	optional,
	s,
	stringType )
import Beng.Things (
	satisfiesThing,
	NamedThing(..),
	NativeOrType(..),
	NativeStringType(..),
	NativeStringValue(..),
	NativeType(..),
	CombinedThings(..) )
import Beng.Types.Build.Context (PrecedenceBound(..))
import Beng.Types.Locations (Builtin(..), BuiltinArg(..), BuiltinProp(..), SomeLocation(..))
import Beng.Types.Things (
	Parameter(..),
	SomeParameterizedThing(..),
	SomeThing(..) )
import qualified Beng.Types.Things as Thing

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
	let thingType = SomeParameterizedThing $ NativeType $ const []
	let parameterFor parentIndex parameterName baseType = Parameter {
			decLoc = SomeLocation $ BuiltinArg { name = parameterName, parentIndex },
			name = parameterName,
			baseType }
	let parameterAt parentIndex parameterName baseType =
		SomeParameterizedThing $ parameterFor parentIndex parameterName baseType

	let decForProp parentIndex propIndex subpatternsFor returnType oneType =
		declare Default (subpatternsFor oneType) returnType
			BuiltinProp { parentIndex, propIndex, one = SomeLocation $ Builtin { index = parentIndex } }
	let defForOp index subpatternsFor returnType run oneType =
		define Default (subpatternsFor oneType) returnType run Builtin { index }
	let defForProp parentIndex propIndex subpatternsFor returnType run oneType =
		define Default (subpatternsFor oneType) returnType run
			BuiltinProp { parentIndex, propIndex, one = SomeLocation $ Builtin { index = parentIndex } }
	let defConstantForOp index subpatternsFor returnType result oneType =
		defForOp index subpatternsFor returnType (const $ return result) oneType
	let defNamedForOp index literal returnType result =
		-- One is unused because there are no arguments in the subpatterns.
		defConstantForOp index (const [l literal]) returnType result thingType
	let defConstantForProp parentIndex propIndex subpatternsFor returnType result oneType =
		defForProp parentIndex propIndex subpatternsFor returnType (const $ return result) oneType

	let soundType = SomeParameterizedThing $ NamedThing "a sound" $
		SomeParameterizedThing NativeStringType

	let yellSubpatternsFor i one = [l "yell", s, l "as", s, a i "One" one]
	let declareYellPropFor i j oneType =
		decForProp i j (yellSubpatternsFor i) soundType oneType
	let defineYellForOp i result oneType =
		defConstantForOp i (yellSubpatternsFor i) soundType
			(SomeThing $ NativeStringValue result) oneType
	let defineYellForProp i j result oneType =
		defConstantForProp i j (yellSubpatternsFor i) soundType
			(SomeThing $ NativeStringValue result) oneType
	
	let animalType = SomeParameterizedThing $ NamedThing "an animal" $
		SomeParameterizedThing $ NativeType
			\one -> do
				let oneType = Thing.parameterize one
				[SomeOperator $ declareYellPropFor 0 0 oneType]
	let animalDef = SomeThing $ defNamedForOp 0 "an animal" animalType $ SomeThing animalType

	let killSubpatternsFor i oneType =
		[l "kill", s, a i "Animal" animalType, s, l "as", s, a i "One" oneType]
	let declareKillFor i j oneType =
		decForProp i j (killSubpatternsFor i) animalType oneType

	let catType = SomeParameterizedThing $ NamedThing "a cat" $
		SomeParameterizedThing $ CombinedThings $ P2.dualton
			animalType $
			SomeParameterizedThing $ NativeType \one -> do
				let oneType = Thing.parameterize one
				[SomeOperator $ declareKillFor 1 0 oneType]
	let catDef = SomeThing $ defNamedForOp 1 "a cat" catType $ SomeThing catType
	let yowlDef = SomeThing $ defineYellForOp 2 "yowl" catType

	let fetchSubpatternsFor i oneType =
		[l "fetch", s, a i "Thing" thingType, s, l "as", s, a i "One" oneType]
	let declareFetchForProp i j oneType =
		decForProp i j (fetchSubpatternsFor i) thingType oneType

	let dogType = SomeParameterizedThing $ NamedThing "a dog" $
		SomeParameterizedThing $ CombinedThings $ P2.dualton animalType $
		SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			[
				SomeOperator $ declareFetchForProp 3 0 oneType,
				SomeOperator $ defineYellForProp 3 1 "bark" oneType]
	let dogDef = SomeThing $ defNamedForOp 3 "a dog" dogType $ SomeThing dogType

	let birthYearSubpatternsFor i oneType = [l "Birth Year for ", a i "One" oneType]
	let declareBirthYearFor i j oneType =
		decForProp i j (birthYearSubpatternsFor i) intType oneType
	let defineBirthYearFor i j result oneType =
		defConstantForProp i j (birthYearSubpatternsFor i) intType (intValue result) oneType

	let goodPortraitSubpatternsFor i oneType = [a i "One" oneType, l " has a good portrait"]
	let defineGoodPortraitFor i j result oneType =
		defConstantForProp i j (goodPortraitSubpatternsFor i) bitType (bitValue result)
			oneType

	let colorfulFurSubpatternsFor i oneType = [a i "One" oneType, l " has colorful fur"]
	let defineColorfulFurFor i j result oneType =
		defConstantForProp i j (colorfulFurSubpatternsFor i) bitType (bitValue result)
			oneType

	let shortFurSubpatternsFor i oneType = [a i "One" oneType, l " has short fur"]
	let defineShortFurFor i j result oneType =
		defConstantForProp i j (shortFurSubpatternsFor i) bitType (bitValue result)
			oneType

	let philosophizeSubpatternsFor i oneType =
		[l "philosophize", s, l "as", s, a i "One" oneType]
	let definePhilosophizeFor i j result oneType =
		defConstantForProp i j (philosophizeSubpatternsFor i) stringType
			(SomeThing $ NativeStringValue result) oneType

	let humanType = SomeParameterizedThing $ NamedThing "a human" $
		SomeParameterizedThing $ CombinedThings $ P2.dualton animalType $
		SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			[
				SomeOperator $ defineYellForProp 4 0 "shout" oneType,
				SomeOperator $ declareBirthYearFor 4 1 oneType,
				SomeOperator $ defineGoodPortraitFor 4 2 True oneType,
				SomeOperator $ defForProp 4 3 (philosophizeSubpatternsFor 4) stringType
					(const $ return $ SomeThing $ NativeStringValue "To be or not to be?")
					oneType]
	let humanDef = SomeThing $ defNamedForOp 4 "a human" humanType $ SomeThing humanType

	let parisHiltonType = SomeParameterizedThing $ NamedThing "Paris Hilton" $
		SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			[
				SomeOperator $ defineYellForProp 5 0 "shout" oneType,
				SomeOperator $ defineBirthYearFor 5 1 1981 oneType,
				SomeOperator $ defineGoodPortraitFor 5 2 True oneType,
				SomeOperator $ definePhilosophizeFor 5 3 "Life is too short to blend in."
					oneType]
	let parisHiltonDef = SomeThing $ defNamedForOp 5 "Paris Hilton" parisHiltonType
		$ SomeThing parisHiltonType

	let opponentSubpatternsFor i oneType = [l "Opponent for ", a i "One" oneType]
	let declareOpponentFor i j returnType oneType =
		decForProp i j (opponentSubpatternsFor i) returnType oneType

	let defeatedSubpatternsFor i oneType = [a i "One" oneType, l " is Defeated"]
	let defineDefeatedFor i j result oneType =
		defConstantForProp i j (defeatedSubpatternsFor i) bitType (bitValue result) oneType

	let defeatedTypeOf index opponentName opponentType = do
		let defeatedType = SomeParameterizedThing $ NamedThing ("a defeated " ++ opponentName) $
				SomeParameterizedThing $ NativeType \one -> do
					let oneType = Thing.parameterize one
					[
						SomeOperator $ declareOpponentFor index 0 opponentType oneType,
						SomeOperator $ defineDefeatedFor index 1 False oneType ]
		defeatedType

	let defeatSubpatternsFor i opponentArgType oneType =
		[l "defeat", s, a i "Opponent" opponentArgType, s, l "as", s, a i "One" oneType]
	let declareDefeatFor i j opponentArgType returnType oneType =
		decForProp i j (defeatSubpatternsFor i opponentArgType) returnType oneType
	let challengeSubpatternsFor i targetArgType oneType =
		[l "challenge", s, a i "Target" targetArgType, s, l "as", s, a i "One" oneType]
	let declareChallengeFor i j targetArgType returnType oneType =
		decForProp i j (challengeSubpatternsFor i targetArgType) returnType oneType
	let
		genericDefeatedOpponentTypeAt :: (Int -> SomeParameterizedThing)
		genericDefeatedOpponentTypeAt index =
			let opponentType = parameterAt index "O" animalType
			in defeatedTypeOf index "opponent" opponentType
		nestedDefeaterTypeOf ::
			(Int -> SomeParameterizedThing -> SomeParameterizedThing -> SomeParameterizedThing)
		nestedDefeaterTypeOf index outerOpponentType outerOneType = do
			let innerOpponentType = parameterAt index "O" $
					SomeParameterizedThing $ NativeOrType $ P2.dualton
						outerOpponentType outerOneType
			let defeatedOpponentType = defeatedTypeOf index "possible loser" innerOpponentType
			SomeParameterizedThing $ NamedThing "a defeater of a possible loser" $
				SomeParameterizedThing $ NativeType \one -> do
					let oneType = Thing.parameterize one
					[
						SomeOperator $ declareDefeatFor index 0 innerOpponentType
							defeatedOpponentType oneType ]
		challengerOf :: (String -> SomeParameterizedThing -> SomeParameterizedThing)
		challengerOf opponentName opponentArgType = SomeParameterizedThing $
			NamedThing ("a challenger of " ++ opponentName) $
				SomeParameterizedThing $ NativeType \one -> do
					let oneType = Thing.parameterize one
					[
						SomeOperator $ declareChallengeFor 24 0 opponentArgType
							(nestedDefeaterTypeOf 23 opponentArgType oneType) oneType ]

	let reneDescartesType = SomeParameterizedThing $ NamedThing "Rene Descartes" $
		SomeParameterizedThing $ CombinedThings $ P2.dualton humanType $
		SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			let opponentType = parameterAt 11 "O" animalType
			[
				SomeOperator $ defineBirthYearFor 6 0 1596 oneType,
				SomeOperator $ definePhilosophizeFor 6 1 "I think, there I am."
					oneType,
				SomeOperator $ declareDefeatFor 11 0 opponentType
					(genericDefeatedOpponentTypeAt 11) oneType ]
	let reneDescartesDef = SomeThing $
		defNamedForOp 6 "Rene Descartes" reneDescartesType $ SomeThing reneDescartesType

	let calicoType = SomeParameterizedThing $ NamedThing "a Calico" $
		SomeParameterizedThing $ CombinedThings $ P2.dualton catType $
		SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			[
				SomeOperator $ defineColorfulFurFor 15 0 True oneType ]
	let calicoDef = SomeThing $ defNamedForOp 15 "a Calico" calicoType $ SomeThing calicoType

	let siameseType = SomeParameterizedThing $ NamedThing "a Siamese" $
		SomeParameterizedThing $ CombinedThings $ P2.dualton catType $
		SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			[
				SomeOperator $ defineShortFurFor 16 0 True oneType ]
	let siameseDef = SomeThing $ defNamedForOp 16 "a Siamese" siameseType $ SomeThing siameseType

	let williamShakespeareType = SomeParameterizedThing $
		NamedThing "William Shakespeare" $ SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			let opponentType = parameterAt 22 "O" animalType
			[
				SomeOperator $ defineYellForProp 7 0 "shout" oneType,
				SomeOperator $ defineBirthYearFor 7 1 1564 oneType,
				SomeOperator $ defineGoodPortraitFor 7 2 True oneType,
				SomeOperator $ declareChallengeFor 22 0 opponentType
					(nestedDefeaterTypeOf 23 opponentType oneType) oneType,
				SomeOperator $ declareDefeatFor 13 0 parisHiltonType
					(defeatedTypeOf 13 "Paris Hilton" parisHiltonType) oneType]
	let williamShakespeareDef = SomeThing $
		defNamedForOp 7 "William Shakespeare" williamShakespeareType $ SomeThing williamShakespeareType

	let bigfootType = SomeParameterizedThing $ NamedThing "Bigfoot" $
		SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			let opponentType = parameterAt 17 "O" animalType
			[
				SomeOperator $ defineYellForProp 8 0 "shout" oneType,
				SomeOperator $ defineBirthYearFor 8 1 1811 oneType,
				SomeOperator $ defineGoodPortraitFor 8 2 False oneType,
				SomeOperator $ definePhilosophizeFor 8 3 "MAKE OWN PATH THRU FOREST" oneType,
				SomeOperator $ declareDefeatFor 17 0 opponentType
					(genericDefeatedOpponentTypeAt 17) oneType ]
	let bigfootDef = SomeThing $ defNamedForOp 8 "Bigfoot" bigfootType $ SomeThing bigfootType

	let votedSubpatternsFor i oneType = [a i "One" oneType, l " voted this year"]
	let declareVotedFor i j oneType =
		decForProp i j (votedSubpatternsFor i) bitType oneType

	let milleniumBabyType = SomeParameterizedThing $
		NamedThing "a millenium baby" $ SomeParameterizedThing $ CombinedThings $ P2.dualton
		humanType $
		SomeParameterizedThing $ NativeType \one -> do
			let oneType = Thing.parameterize one
			[
				SomeOperator $ defineBirthYearFor 9 0 2000 oneType,
				SomeOperator $ declareVotedFor 9 1 oneType]
	let milleniumBabyDef = SomeThing $
		defNamedForOp 9 "a millenium baby" milleniumBabyType $ SomeThing milleniumBabyType

	let defeaterOf opponentName opponentArgType = SomeParameterizedThing $
		NamedThing ("a defeater of " ++ opponentName) $
				SomeParameterizedThing $ NativeType \one -> do
					let oneType = Thing.parameterize one
					[
						SomeOperator $ declareDefeatFor 12 0 opponentArgType
							(defeatedTypeOf 12 opponentName opponentArgType) oneType ]
	let brokenDogDefeaterType = SomeParameterizedThing $
		NamedThing "a dog that defeats a cat badly" $
			SomeParameterizedThing $ CombinedThings $ P2.dualton dogType $
			SomeParameterizedThing $ NativeType \one -> do
				let oneType = Thing.parameterize one
				[
					SomeOperator $ declareDefeatFor 14 0 catType
						(defeatedTypeOf 14 "a dog" dogType) oneType ]

	let motherType = parameterAt 18 "Mother" calicoType
	let fatherType = parameterAt 18 "Father" siameseType
	let breedSubpatternsFor i motherArgType fatherArgType oneType =
		[l "breed", s, l "with", s, a i "Father" fatherArgType, s, l "as", s,
			a i "Mother" motherArgType, s, l "as", s, a i "One" oneType]
	let declareBreedFor i j motherArgType fatherArgType returnType oneType =
		decForProp i j (breedSubpatternsFor i motherArgType fatherArgType) returnType oneType
	let calicoSiameseKittenType = SomeParameterizedThing $ NamedThing "a Calico-Siamese kitten" $
		SomeParameterizedThing $ CombinedThings $ P2.dualton calicoType siameseType
	let brokenCalicoChildType = SomeParameterizedThing $ NamedThing "a bad Calico kitten" $
		SomeParameterizedThing $ CombinedThings $ P2.dualton calicoType calicoType
	let breedableType = SomeParameterizedThing $ NamedThing "a breedable cat" $
		SomeParameterizedThing $ NativeType \_ -> [
			SomeOperator $ declareBreedFor 18 0 motherType fatherType
				(SomeParameterizedThing $ CombinedThings $ P2.dualton motherType fatherType)
				catType ]
	let brokenCalicoBreedableType = SomeParameterizedThing $
		NamedThing "a badly breedable Calico" $
			SomeParameterizedThing $ CombinedThings $ P2.dualton calicoType $
			SomeParameterizedThing $ NativeType \one -> do
				let oneType = Thing.parameterize one
				[
					SomeOperator $ declareBreedFor 21 0 calicoType siameseType
						brokenCalicoChildType oneType ]

	{- Note that the way this context is assembled is not necessarily the way context is really handled;
		most notably, the properties of a thing should always be treated as the top of the context stack
		wherever the thing is used as an argument, but here, all the properties are flattened. -}
	let context = Context.fromThings [
		animalDef,
		catDef,
		yowlDef,
		dogDef,
		humanDef,
		calicoDef,
		siameseDef,
		parisHiltonDef,
		reneDescartesDef,
		williamShakespeareDef,
		bigfootDef,
		milleniumBabyDef ]

	let assertSatisfies candidate requirement =
		() <$ mapError msg ((context, candidate) `satisfiesThing` requirement)
	let assertDoesNotSatisfy candidate requirement =
		assertSatisfies candidate requirement `hasErrorElse`
			"This should not have been satisfied!"
	let compareSubpatternsFor i opponentArgType witnessArgType oneType = [
			l "compare", s, a i "Opponent" opponentArgType, s, l "with", s,
			a i "Witness" witnessArgType, s, l "as", s, a i "One" oneType ]
	let separatedOperatorCandidateType = do
		let candidateParameter = parameterAt 25 "O" animalType
		let candidateOperator = decForProp 25 0
				(compareSubpatternsFor 34 candidateParameter reneDescartesType)
				(defeatedTypeOf 35 "candidate opponent" candidateParameter)
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator candidateOperator]
	let separatedOperatorRequirementType = do
		let requirementParameter = parameterAt 26 "O" animalType
		let requirementOperator = decForProp 26 0
				(compareSubpatternsFor 34 parisHiltonType requirementParameter)
				(defeatedTypeOf 36 "requirement opponent" requirementParameter)
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator requirementOperator]
	let positiveOperatorCandidateType = do
		let candidateParameter = parameterAt 29 "O" animalType
		let candidateOperator = decForProp 29 0
				(compareSubpatternsFor 38 candidateParameter parisHiltonType)
				(SomeParameterizedThing $ CombinedThings $
					P2.dualton candidateParameter parisHiltonType)
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator candidateOperator]
	let positiveOperatorRequirementType = do
		let requirementParameter = parameterAt 30 "O" animalType
		let requirementOperator = decForProp 30 0
				(compareSubpatternsFor 38 reneDescartesType requirementParameter)
				(SomeParameterizedThing $ CombinedThings $
					P2.dualton reneDescartesType requirementParameter)
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator requirementOperator]
	let repeatedParameterCandidateType = do
		let candidateParameter = parameterAt 27 "O" thingType
		let candidateOperator = decForProp 27 0
				(compareSubpatternsFor 37 candidateParameter candidateParameter)
				thingType
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator candidateOperator]
	let repeatedParameterRequirementType = do
		let requirementOperator = decForProp 28 0
				(compareSubpatternsFor 37 soundType intType)
				thingType
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator requirementOperator]
	let defaultSubpatternsFor i maybeArgType oneType =
		[l "default", a i "One" oneType, optional (a i "Maybe" maybeArgType)]
	let optionalFallbackCandidateType = do
		let maybeParameter = parameterAt 31 "Maybe" animalType
		let candidateOperator = decForProp 31 0
				(defaultSubpatternsFor 39 maybeParameter)
				maybeParameter
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator candidateOperator]
	let optionalFallbackRequirementType = do
		let requirementOperator = decForProp 32 0
				(\oneType -> [l "default", a 32 "One" oneType])
				animalType
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator requirementOperator]
	let siblingParameterCandidateType = do
		let leftParameter = parameterAt 33 "Left" thingType
		let rightParameter = parameterAt 33 "Right" thingType
		let candidateOperator = decForProp 33 0
				(\oneType -> [
					l "pair", s, a 40 "Left" leftParameter, s, l "with", s,
					a 40 "Right" rightParameter, s, l "as", s, a 40 "One" oneType ])
				(SomeParameterizedThing $ CombinedThings $ P2.dualton
					leftParameter rightParameter)
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator candidateOperator]
	let siblingParameterRequirementType = do
		let requirementOperator = decForProp 34 0
				(\oneType -> [
					l "pair", s, a 40 "Left" intType, s, l "with", s,
					a 40 "Right" soundType, s, l "as", s, a 40 "One" oneType ])
				(SomeParameterizedThing $ CombinedThings $ P2.dualton intType soundType)
				thingType
		SomeParameterizedThing $ NativeType \_ -> [SomeOperator requirementOperator]

	[
		PureTests "equal" [
			("native basic", SomeThing soundType `assertSatisfies` soundType),
			("native constructed type", SomeThing catType `assertSatisfies` catType),
			("thing value", SomeThing reneDescartesType `assertSatisfies` reneDescartesType) ],
		PureTests "satisfies by props" [
			("human is an animal", SomeThing humanType `assertSatisfies` animalType),
			("Rene is a human", SomeThing reneDescartesType `assertSatisfies` humanType),
			("a millenium baby is a human",
				SomeThing milleniumBabyType `assertSatisfies` humanType) ],
		PureTests "satisfies by context" [
			("cat is an animal", SomeThing catType `assertSatisfies` animalType),
			("Paris Hilton is a human", SomeThing parisHiltonType `assertSatisfies` humanType),
			("William Shakespeare is a human",
				SomeThing williamShakespeareType `assertSatisfies` humanType) ],
		PureTests "parameters" [
			("Rene Descartes defeats Paris Hilton",
				SomeThing reneDescartesType `assertSatisfies` defeaterOf "Paris Hilton" parisHiltonType),
			("Rene Descartes does not defeat a sound",
				SomeThing reneDescartesType `assertDoesNotSatisfy` defeaterOf "a sound" soundType),
			("Bigfoot defeats Rene Descartes",
				SomeThing bigfootType `assertSatisfies` defeaterOf "Rene Descartes" reneDescartesType),
			("William Shakespeare defeats Paris Hilton",
				SomeThing williamShakespeareType `assertSatisfies`
					defeaterOf "Paris Hilton" parisHiltonType),
			("William Shakespeare is a challenger of Rene Descartes",
				SomeThing williamShakespeareType `assertSatisfies`
					challengerOf "Rene Descartes" reneDescartesType),
			("William Shakespeare does not defeat Rene Descartes",
				SomeThing williamShakespeareType `assertDoesNotSatisfy`
					defeaterOf "Rene Descartes" reneDescartesType),
			("operator comparison separates same-named parameters on both sides",
				SomeThing separatedOperatorCandidateType `assertDoesNotSatisfy`
					separatedOperatorRequirementType),
			("operator comparison resolves parameters on both sides",
				SomeThing positiveOperatorCandidateType `assertSatisfies`
					positiveOperatorRequirementType),
			("a repeated parameter must satisfy its previously known bindings",
				SomeThing repeatedParameterCandidateType `assertDoesNotSatisfy`
					repeatedParameterRequirementType),
			("an optional unbound parameter resolves to its base type",
				SomeThing optionalFallbackCandidateType `assertSatisfies`
					optionalFallbackRequirementType),
			("sibling thing-bounded parameters resolve independently",
				SomeThing siblingParameterCandidateType `assertSatisfies`
					siblingParameterRequirementType),
			("a Calico-Siamese kitten is a Calico",
				SomeThing calicoSiameseKittenType `assertSatisfies` calicoType),
			("a Calico-Siamese kitten is a Siamese",
				SomeThing calicoSiameseKittenType `assertSatisfies` siameseType),
			("a badly breedable Calico does not satisfy a breedable cat",
				SomeThing brokenCalicoBreedableType `assertDoesNotSatisfy` breedableType),
			("a dog cannot defeat a cat with the wrong defeated return type",
				SomeThing brokenDogDefeaterType `assertDoesNotSatisfy`
					defeaterOf "a cat" catType) ],
		PureTests "does not satisfy" [
			("Rene is not a sound",
				SomeThing reneDescartesType `assertDoesNotSatisfy` soundType),
			("Rene is not a cat", SomeThing reneDescartesType `assertDoesNotSatisfy` catType),
			("William Shakespeare is not a dog",
				SomeThing williamShakespeareType `assertDoesNotSatisfy` dogType),
			("Bigfoot is not a human", SomeThing bigfootType `assertDoesNotSatisfy` humanType),
			("Paris is not a millenium baby",
				SomeThing parisHiltonType `assertDoesNotSatisfy` milleniumBabyType) ]]
