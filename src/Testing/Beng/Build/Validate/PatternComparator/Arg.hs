module Testing.Beng.Build.Validate.PatternComparator.Arg (
	testArg
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Types.Locations (Builtin(..), SomeLocation(..))
import Beng.Types.Parse.Patterns (Argument(..), SomePattern(..))
import Beng.Things (NativeBitsType(..), PatternType(..))
import Beng.Types.Things (SomeParameterizedThing(..))

testArg :: TestCategory
testArg = TestCategories "Arg" do
	let a name argType = SomePattern Argument {
		name, argType, decLoc = SomeLocation $ Builtin 1 {- unused -}}
	let intType = SomeParameterizedThing $ NativeBitsType 32
	let bitType = SomeParameterizedThing $ NativeBitsType 1
	[
		PureTests "satisfies" [
			("exact", a "Int" intType `assertSatisfies` a "Int" intType),
			("requirement type", a "Bit" intType `assertSatisfies` a "Bit" bitType),
			("wrong name", a "Int" intType `assertSatisfies` a "Number" intType) ],
		PureTests "does not satisfy" [
			("candidate type", a "Int" bitType `assertDoesNotSatisfy` a "Int" intType),
			("disparate type", a "Int" intType `assertDoesNotSatisfy`
				a "Int" (SomeParameterizedThing PatternType)) ]]
