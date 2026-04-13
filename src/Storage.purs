module Storage where

import Prelude
import Data.Maybe (Maybe(..))
import Effect (Effect)

foreign import getItemImpl
  :: forall a. a -> (String -> a) -> String -> Effect a

foreign import setItemImpl  :: String -> String -> Effect Unit
foreign import removeItemImpl :: String -> Effect Unit
foreign import reloadImpl   :: Effect Unit
foreign import generateUUIDImpl :: Effect String

getItem :: String -> Effect (Maybe String)
getItem = getItemImpl Nothing Just

setItem :: String -> String -> Effect Unit
setItem = setItemImpl

removeItem :: String -> Effect Unit
removeItem = removeItemImpl

reload :: Effect Unit
reload = reloadImpl

generateUUID :: Effect String
generateUUID = generateUUIDImpl