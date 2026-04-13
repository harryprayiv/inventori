module Codec where

import Prelude

import Data.Either (Either)
import Data.List.NonEmpty (NonEmptyList)
import Data.Map (Map)
import Data.Map as Map
import Data.Tuple (Tuple(..))
import Foreign (ForeignError)
import Foreign.Object (Object)
import Foreign.Object as Obj
import Types (CountData, Inventory, ItemData, SourceHash)
import Yoga.JSON (readJSON, writeJSON)

type YogaError = NonEmptyList ForeignError

-- ---------------------------------------------------------------------------
-- Map <-> Object
-- ---------------------------------------------------------------------------

objectToMap :: forall v. Object v -> Map String v
objectToMap = Map.fromFoldable <<< (Obj.toUnfoldable :: Object v -> Array (Tuple String v))

mapToObject :: forall v. Map String v -> Object v
mapToObject = Obj.fromFoldable <<< (Map.toUnfoldable :: Map String v -> Array (Tuple String v))

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------

readInventory :: String -> Either YogaError Inventory
readInventory s = do
  o <- readJSON s :: Either YogaError (Object (Object (Array String)))
  pure $ objectToMap (map objectToMap o)

-- ---------------------------------------------------------------------------
-- CountData
-- ---------------------------------------------------------------------------

readCountData :: String -> Either YogaError CountData
readCountData s = do
  o <- readJSON s :: Either YogaError (Object (Object (Object ItemData)))
  pure $ objectToMap (map (objectToMap <<< map objectToMap) o)

writeCountData :: CountData -> String
writeCountData cd =
  writeJSON (mapToObject (map (mapToObject <<< map mapToObject) cd))

-- ---------------------------------------------------------------------------
-- ExportEnvelope
-- ---------------------------------------------------------------------------

type EnvelopeWire =
  { sourceHash :: SourceHash
  , counts     :: Object (Object (Object ItemData))
  }

writeExportEnvelope :: SourceHash -> CountData -> String
writeExportEnvelope hash cd =
  writeJSON
    { sourceHash: hash
    , counts: mapToObject (map (mapToObject <<< map mapToObject) cd)
    }

readExportEnvelope :: String -> Either YogaError { sourceHash :: SourceHash, counts :: CountData }
readExportEnvelope s = do
  env <- readJSON s :: Either YogaError EnvelopeWire
  pure
    { sourceHash: env.sourceHash
    , counts: objectToMap (map (objectToMap <<< map objectToMap) env.counts)
    }