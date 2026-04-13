module Logic where

import Prelude

import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Tuple (Tuple(..))
import Types (CountData, Inventory, ItemData, VisitorId)

-- ---------------------------------------------------------------------------
-- Empty CountData skeleton from an Inventory
-- ---------------------------------------------------------------------------

emptyCountData :: VisitorId -> Inventory -> CountData
emptyCountData vid inv =
  map
    ( map
        ( \items ->
            Array.foldl
              (\acc item -> Map.insert item { count: 0, addedBy: vid, notes: [] } acc)
              Map.empty
              items
        )
    )
    inv

-- ---------------------------------------------------------------------------
-- Merge two CountData maps (additive)
-- ---------------------------------------------------------------------------

mergeCountData :: CountData -> CountData -> CountData
mergeCountData base incoming =
  Map.unionWith (Map.unionWith (Map.unionWith mergeItem)) base incoming
  where
  mergeItem :: ItemData -> ItemData -> ItemData
  mergeItem a b =
    { count  : a.count + b.count
    , addedBy: a.addedBy
    , notes  : a.notes <> b.notes
    }

-- ---------------------------------------------------------------------------
-- Apply a count delta; returns Nothing if result would go negative
-- ---------------------------------------------------------------------------

applyDelta
  :: VisitorId
  -> String -> String -> String
  -> Int
  -> CountData
  -> Maybe CountData
applyDelta vid main sub item delta cd =
  let
    existing :: ItemData
    existing = fromMaybe { count: 0, addedBy: vid, notes: [] }
      $ Map.lookup item =<< Map.lookup sub =<< Map.lookup main cd

    newCount = existing.count + delta
  in
    if newCount < 0 then Nothing
    else
      let
        newItem = existing
          { count = newCount
          , notes = Array.snoc existing.notes { visitorId: vid, delta }
          }
        newLeaf = Map.insert item newItem
          (fromMaybe Map.empty (Map.lookup sub =<< Map.lookup main cd))
        newMid  = Map.insert sub newLeaf
          (fromMaybe Map.empty (Map.lookup main cd))
      in
        Just (Map.insert main newMid cd)

-- ---------------------------------------------------------------------------
-- Override a count; returns (delta, newData) or Nothing if newCount < 0
-- ---------------------------------------------------------------------------

setCount
  :: VisitorId
  -> String -> String -> String
  -> Int
  -> CountData
  -> Maybe (Tuple Int CountData)
setCount vid main sub item newCount cd =
  let
    existing = fromMaybe { count: 0, addedBy: vid, notes: [] }
      $ Map.lookup item =<< Map.lookup sub =<< Map.lookup main cd
    delta = newCount - existing.count
  in
    if newCount < 0 then Nothing
    else
      let
        newItem = existing
          { count = newCount
          , notes = Array.snoc existing.notes { visitorId: vid, delta }
          }
        newLeaf = Map.insert item newItem
          (fromMaybe Map.empty (Map.lookup sub =<< Map.lookup main cd))
        newMid  = Map.insert sub newLeaf
          (fromMaybe Map.empty (Map.lookup main cd))
      in
        Just (Tuple delta (Map.insert main newMid cd))

-- ---------------------------------------------------------------------------
-- Post-import repair
-- ---------------------------------------------------------------------------

repairNotes :: CountData -> CountData
repairNotes = map (map (map \item -> item { notes = item.notes }))