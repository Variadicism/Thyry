module Testing.Beng.Build.Validate.PatternComparator.Arg (
	testArg
) where

import Utils.Testing

import Testing.Beng.Build.Validate.PatternComparator.Utils (assertSatisfies, assertDoesNotSatisfy)

import Beng.Types.Locations (Location(Builtin))
import Beng.Types.Parse.Patterns (ArgP(..), Argument(..), SomePattern(..))
import Beng.Things (NativeBitsType(..), PatternType(..))
import Beng.Types.Things (SomeThing(..))

testArg :: TestCategory
testArg = TestCategories "Arg" do
	let a name argType = SomePattern $ ArgP Argument { name, argType, decLoc = Builtin 1 {- unused -}}
	let intType = SomeThing $ NativeBitsType 32
	let bitType = SomeThing $ NativeBitsType 1
	[
		PureTests "satisfies" [
			("exact", a "Int" intType `assertSatisfies` a "Int" intType),
			("super type", a "Bit" intType `assertSatisfies` a "Bit" bitType),
			("wrong name", a "Int" intType `assertSatisfies` a "Number" intType) ],
		PureTests "does not satisfy" [
			("sub type", a "Int" bitType `assertDoesNotSatisfy` a "Int" intType),
			("disparate type", a "Int" intType `assertDoesNotSatisfy` a "Int" (SomeThing PatternType)) ]]
