module Beng.Parse.Matches where

import Utils.Messaging (Messagable)

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

instance Eq And
instance Eq Argument
instance Eq CharClass
instance Eq Delimited
instance Eq Literal
instance Eq NamedText
instance Eq Or
instance Eq SomeMatch
instance Eq Space

instance Show And
instance Show Argument
instance Show CharClass
instance Show Delimited
instance Show Literal
instance Show NamedText
instance Show Or
instance Show Space

instance Messagable And
instance Messagable Argument
instance Messagable CharClass
instance Messagable Delimited
instance Messagable Literal
instance Messagable NamedText
instance Messagable Or
instance Messagable SomeMatch
instance Messagable Space

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
