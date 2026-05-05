module Beng.Build.TypeTest where

import Beng.Types.Build.Context (Context)
import Beng.Types.Build.TypeTest
import Beng.Types.Things (SomeParameterizedThing)

fromContext :: Context -> SomeParameterizedThing -> SomeParameterizedThing -> TypeTest

satisfiesDuring
	:: (TypeTest, SomeParameterizedThing) -> SomeParameterizedThing -> TypeTestProgressResult

runTestProgress :: TypeTest -> TypeTestProgressResult

runTest :: TypeTest -> TypeTestResult
