module Testing.Beng.Build.Validate.Typecheck (
	testTypecheck
) where

-- tests

testTypecheck :: TestCategory
testTypecheck = TestCategories "typecheck" do
	{- Beng equivalent:
		sound := a native string
		
		animal := a thing with
		    yell as 'one' => a sound :/=
		
		cat := an animal with
		    kill 'Animal, an animal' as 'one' => animal :/=
		    yell as 'one' := "yowl"
		
		dog := an animal with
		    fetch 'Thing, a thing' as 'one' => thing :/=
		    yell as 'one' := "bark"
		
		human := a type of animal with
		    yell as 'one' := "shout"
		    philosophize as 'one' => a native string :=
		        "To be or not to be?"
		
		Paris Hilton := a human
		
		Rene Descartes := a human with
		    philosophize as 'one' := "I think, therefore I am."	-}

	let decCardFor index subpatternsFor returnType one =
		DecCard $ declare Default (subpatternsFor one) returnType (Builtin index)
	let defCardFor index subpatternsFor returnType run one =
		DefCard $ define Default (subpatternsFor one) sound run (Builtin index)

	let sound = ThingType { name = Just "sound", parents = [NativeStringType], properties = const [] }

	let yellSubpatternsFor i one = [l "yell", s, l "as", s, argOfBuiltin i "One" one]
	let yellCardFor = decCardFor 0 (yellSubpatternsFor 0) sound
	let animal = ThingType { name = Just "animal", parents = [], properties = \one -> [yellCardFor one] }

	let defineYellAsFor i result = defCardFor index (yellSubpatternsFor i) sound $ const $ return result

	let killSubpatternsFor one =
		[l "kill", argOfBuiltin 1 "Animal" animal, s, l "as", s, argOfBuiltin 1 "One" one]
	let killCardFor = decCardFor 1 killSubpatternsFor animal
	let cat = ThingType { name = Just "cat", parents = [animal],
		properties = \one -> [killCardFor one, defineYellAsFor 2 "yowl" one] }

	let fetchSubpatternsFor one =
		[l "fetch", argOfBuiltin 3 "Thing" thing, s, l "as", s, argOfBuiltin 3 "One" one]
	let fetchCardFor = decCardFor 3 fetchCardFor thing
	let dog = ThingType { name = Just "dog", parents = [animal],
		properties = \one -> [fetchCardFor one, defineYellAsFor 4 "bark" one] }

	let philosophizeSubpatternsFor one = [l "philosophize", s, l "as", s, argOfBuiltin 5 "One" one]
	let philosophizeCardFor = decCardFor 5 philosophizeSubpatternsFor NativeStringType
	let defineYellAsShoutFor = defineYellAsFor 6 "shout"
	let human = ThingType { name = Just "human", parents = [animal],
		properties = \one -> [philosophizeCardFor one, defineYellAsShoutFor one] }

	let reneQuote = NativeStringValue "I think, therefore I am."
	let reneDescartes = ThingValue \one -> Populace (defineYellAsShoutFor $ ConstantType reneDescartes)
		[defCardFor 7 philosophizeSubpatternsFor (ConstantType reneQuote)
			(const $ return reneQuote) $ ConstantType reneDescartes]
	[
	 ]