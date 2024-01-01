module Beng.Read.Types.Context (
	Context(..)
) where

import Beng.Types.Ops (OpDeclaration, OpDefinition)

data Context = Context {
	precedence :: [[OpDeclaration]],  -- Declarations grouped by precedence 
										-- Lower index -> lower/broader precedence
	definitions :: [OpDefinition] }  -- Definitions stack
										-- Lower index -> defined later/closer (first dibs)