module Beng.Parse.Matches where

import Beng.Types.Parse.Matches (
	And,
	Argument,
	CharClass,
	Delimited,
	DelimitedTail,
	Literal,
	Match(..),
	NamedText,
	Or,
	SomeMatch,
	Space)

instance Match And
instance Match Argument
instance Match CharClass
instance Match Delimited
instance Match Literal
instance Match NamedText
instance Match Or
instance Match SomeMatch
instance Match Space
instance Show DelimitedTail
instance Show SomeMatch

asMatch :: Match m => SomeMatch -> Maybe m
hasArgs :: SomeMatch -> Bool
