module Beng.Build.TypeTest where

import Beng.Types.Build.Context (Context)
import Beng.Types.Build.TypeTest
import Beng.Types.Things (Thing)

fromContext :: Context -> Thing -> Thing -> TypeTest

satisfiesDuring :: (TypeTest, Thing) -> Thing -> TypeTestResult

runTest :: TypeTest -> TypeTestResult
