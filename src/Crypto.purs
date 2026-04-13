module Crypto where

import Prelude
import Effect.Aff (Aff)
import Effect.Aff.Compat (EffectFnAff, fromEffectFnAff)

foreign import sha256HexImpl :: String -> EffectFnAff String

sha256Hex :: String -> Aff String
sha256Hex = fromEffectFnAff <<< sha256HexImpl