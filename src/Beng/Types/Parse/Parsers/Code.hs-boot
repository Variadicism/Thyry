module Beng.Types.Parse.Parsers.Code where

import qualified Beng.Types.Parse.Parsers as General

import Data.Text.Lazy (Text)

data PrefixState

data SpaceState

data State

type Parse t = General.Parse Text State t

type Parser t = General.Parser Text State t
