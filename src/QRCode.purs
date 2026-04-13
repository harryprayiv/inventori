module QRCode where

import Prelude
import Effect (Effect)
import Web.DOM.Element (Element)

-- Thin binding to qrcodejs (loaded via CDN script tag in index.html)
foreign import makeQRCodeImpl
  :: Element
  -> String   -- url
  -> Int      -- width
  -> Int      -- height
  -> Effect Unit

makeQRCode :: Element -> String -> Effect Unit
makeQRCode el url = makeQRCodeImpl el url 90 90