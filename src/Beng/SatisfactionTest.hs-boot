module Beng.SatisfactionTest where

import Beng.Types.Build.Context (Context)
import Beng.Types.SatisfactionTest
import Beng.Types.Things (Thing)

fromContext :: Context -> Thing -> Thing -> SatisfactionTest

satisfiesDuring :: (SatisfactionTest, Thing) -> Thing -> SatisfactionTestResult

runTest :: SatisfactionTest -> SatisfactionTestResult
