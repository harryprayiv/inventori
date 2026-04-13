module Types where

import Data.Map (Map)

type VisitorId  = String
type ItemName   = String
type SubCat     = String
type MainCat    = String
type SourceHash = String

-- inventory.json shape: MainCat -> SubCat -> [ItemName]
type Inventory = Map MainCat (Map SubCat (Array ItemName))

-- Stored as { visitorId, delta } — yoga-json derives the record instance automatically
type Note =
  { visitorId :: VisitorId
  , delta     :: Int
  }

type ItemData =
  { count   :: Int
  , addedBy :: VisitorId
  , notes   :: Array Note
  }

-- Three-level count map
type CountData = Map MainCat (Map SubCat (Map ItemName ItemData))