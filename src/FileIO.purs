module FileIO where

import Prelude
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Compat (EffectFnAff, fromEffectFnAff)
import Web.File.File (File)

-- Read a File as text, returning its content and SHA-256 hex hash
foreign import readFileImpl
  :: File
  -> EffectFnAff { content :: String, hash :: String }

readFile :: File -> Aff { content :: String, hash :: String }
readFile = fromEffectFnAff <<< readFileImpl

-- Trigger a browser download of a string blob
foreign import downloadStringImpl
  :: String   -- filename
  -> String   -- mimeType ("application/json" | "text/csv")
  -> String   -- content
  -> Effect Unit

downloadString :: String -> String -> String -> Effect Unit
downloadString = downloadStringImpl

-- Show the Nedry error overlay for 2 seconds
foreign import showErrorOverlayImpl :: Effect Unit

showErrorOverlay :: Effect Unit
showErrorOverlay = showErrorOverlayImpl