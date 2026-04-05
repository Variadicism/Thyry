module Beng.Build.Invocations where

import Beng.Types.Parse.Parsers.Code (Parser)
import Beng.Types.Invocations (SomeInvocation)

build :: String -> Parser SomeInvocation
