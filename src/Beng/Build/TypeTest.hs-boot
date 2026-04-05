module Beng.Build.TypeTest where

import Beng.Types.Build.Context (Context)
import Beng.Types.Build.TypeTest
import Beng.Types.Things (SomeThing)

fromContext :: Context -> SomeThing -> SomeThing -> TypeTest

satisfiesDuring :: (TypeTest, SomeThing) -> SomeThing -> TypeTestResult

runTest :: TypeTest -> TypeTestResult
