module Main where

import Prelude

import Codec (readCountData, readExportEnvelope, readInventory, writeCountData, writeExportEnvelope)
import Data.Array as Array
import Data.Either (Either(..), hush)
import Data.Foldable (for_)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String as String
import Data.Tuple (Tuple(..), fst, snd)
import Data.Tuple.Nested ((/\))
import Deku.Control (text, text_)
import Deku.Core (Nut, fixed)
import Deku.DOM as D
import Deku.DOM.Attributes as DA
import Deku.DOM.Listeners as DL
import Deku.Do as Deku
import Deku.Hooks (useHot, (<#~>))
import Deku.Toplevel (runInBody)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import FileIO (downloadString, readFile, showErrorOverlay)
import FRP.Poll (Poll)
import Fetch (fetch)
import Logic (applyDelta, mergeCountData, repairNotes, setCount)
import QRCode (makeQRCode)
import Storage (generateUUID, getItem, reload, removeItem, setItem)
import Types (CountData, Inventory, VisitorId)
import Web.Event.Event (target)
import Web.File.FileList as FileList
import Web.HTML (window)
import Web.HTML.HTMLInputElement as HInput
import Web.HTML.HTMLSelectElement as HSelect
import Web.HTML.Window (location)
import Web.HTML.Location (href)
import Yoga.JSON (readJSON, writeJSON)

-- ---------------------------------------------------------------------------
-- Storage keys
-- ---------------------------------------------------------------------------

keyCountData      :: String
keyCountData      = "countData"
keyListName       :: String
keyListName       = "listName"
keySourceHash     :: String
keySourceHash     = "sourceHash"
keyVisitorId      :: String
keyVisitorId      = "visitorId"
keyImportedHashes :: String
keyImportedHashes = "importedFileHashes"

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

loadCountData :: Effect CountData
loadCountData = do
  ms <- getItem keyCountData
  pure $ fromMaybe Map.empty $ ms >>= (hush <<< readCountData)

saveCountData :: CountData -> Effect Unit
saveCountData cd = setItem keyCountData (writeCountData cd)

loadImportedHashes :: Effect (Array String)
loadImportedHashes = do
  ms <- getItem keyImportedHashes
  pure $ fromMaybe [] $ ms >>= (hush <<< readJSON)

saveImportedHashes :: Array String -> Effect Unit
saveImportedHashes hs = setItem keyImportedHashes (writeJSON hs)

buildCSV :: CountData -> String
buildCSV cd =
  let
    header = "Count,Diff,Item,Type,Category"
    rows = do
      Tuple main subs  <- Map.toUnfoldable cd
      Tuple sub  items <- Map.toUnfoldable subs
      Tuple item idata <- Map.toUnfoldable items
      let diff = fromMaybe "" (map (show <<< _.delta) (Array.last idata.notes))
      pure (String.joinWith "," [show idata.count, diff, item, sub, main])
  in
    String.joinWith "\n" (Array.cons header rows)

-- ---------------------------------------------------------------------------
-- App entry point
-- ---------------------------------------------------------------------------

main :: Effect Unit
main = do
  mVid <- getItem keyVisitorId
  vid <- case mVid of
    Just v  -> pure v
    Nothing -> do
      v <- generateUUID
      setItem keyVisitorId v
      pure v

  initialCount <- loadCountData
  initialName  <- map (fromMaybe "NewCount") (getItem keyListName)

  void $ runInBody (app vid initialCount initialName)

-- ---------------------------------------------------------------------------
-- App
-- ---------------------------------------------------------------------------

app :: VisitorId -> CountData -> String -> Nut
app vid initialCount initialName = Deku.do
  setInventory  /\ inventoryValue  <- useHot (Map.empty :: Inventory)
  setCountData  /\ countDataValue  <- useHot initialCount
  setListName   /\ listNameValue   <- useHot initialName
  setSelMain    /\ selMainValue    <- useHot ""
  setSelSub     /\ selSubValue     <- useHot ""
  setSelItem    /\ selItemValue    <- useHot ""
  setStatus     /\ statusValue     <- useHot ""
  setCountInput /\ countInputValue <- useHot 1

  let
    updateCountData :: CountData -> Effect Unit
    updateCountData cd = do
      saveCountData cd
      setCountData cd

  D.div
    [ DL.load_ \_ -> launchAff_ do
        result <- fetch "./inventory.json" {}
        body   <- result.text
        liftEffect case readInventory body of
          Left _    -> showErrorOverlay
          Right inv -> do
            setInventory inv
            let firstMain = fromMaybe "" (map _.key (Map.findMin inv))
            setSelMain firstMain
            let firstSub = fromMaybe "" do
                  subs <- Map.lookup firstMain inv
                  map _.key (Map.findMin subs)
            setSelSub firstSub
            let firstItem = fromMaybe "" do
                  subs  <- Map.lookup firstMain inv
                  items <- Map.lookup firstSub subs
                  Array.head items
            setSelItem firstItem
    ]

    -- Header
    [ D.header [ DA.klass_ "header" ]
        [ D.div [ DA.klass_ "title-and-qr" ]
            [ D.div [ DA.id_ "qrcode" ] []
            , D.span [ DA.id_ "list-name" ] [ text listNameValue ]
            ]
        , D.div [ DA.klass_ "import-export" ]
            [ D.button
                [ DL.click_ \_ -> do
                    cur <- map (fromMaybe "NewCount") (getItem keyListName)
                    setListName cur
                    setItem keyListName cur
                ]
                [ text_ "Rename" ]

            , D.label [ DA.klass_ "file-label", DA.for_ "import-list" ]
                [ text_ "Import Count" ]
            , D.input
                [ DA.xtype_ "file"
                , DA.id_ "import-list"
                , DA.klass_ "hidden"
                , DA.accept_ ".json"
                , DL.change_ \e -> do
                    let mInput = target e >>= HInput.fromEventTarget
                    for_ mInput \fi -> do
                      mFiles <- HInput.files fi
                      for_ mFiles \lst ->
                        for_ (FileList.item 0 lst) \f ->
                          launchAff_ do
                            { content, hash } <- readFile f
                            liftEffect do
                              imported <- loadImportedHashes
                              if Array.elem hash imported
                                then do
                                  showErrorOverlay
                                  setStatus "File already imported."
                                else do
                                  storedHash <- map (fromMaybe "") (getItem keySourceHash)
                                  case readExportEnvelope content of
                                    Left _ -> do
                                      showErrorOverlay
                                      setStatus "Invalid import format."
                                    Right env -> do
                                      when (env.sourceHash /= storedHash) do
                                        showErrorOverlay
                                        setStatus "Warning: inventory source mismatch."
                                      cd <- loadCountData
                                      let merged = repairNotes (mergeCountData cd env.counts)
                                      updateCountData merged
                                      saveImportedHashes (Array.snoc imported hash)
                ]
                []

            , D.button
                [ DL.click_ \_ -> do
                    cd   <- loadCountData
                    name <- map (fromMaybe "Count") (getItem keyListName)
                    downloadString (name <> ".json") "application/json"
                      (writeExportEnvelope "" cd)
                ]
                [ text_ "Export JSON" ]

            , D.button
                [ DL.click_ \_ -> do
                    cd   <- loadCountData
                    name <- map (fromMaybe "Count") (getItem keyListName)
                    downloadString (name <> ".csv") "text/csv" (buildCSV cd)
                ]
                [ text_ "Export CSV" ]
            ]
        ]

    -- Controls row
    , D.div [ DA.klass_ "controls" ]

        -- Main category select
        [ inventoryValue <#~> \inv ->
            D.select
              [ DL.change_ \e ->
                  for_ (target e >>= HSelect.fromEventTarget) \el -> do
                    v <- HSelect.value el
                    setSelMain v
                    let firstSub = fromMaybe "" do
                          subs <- Map.lookup v inv
                          map _.key (Map.findMin subs)
                    setSelSub firstSub
              ]
              ( map (\(Tuple cat _) -> D.option [ DA.value_ cat ] [ text_ cat ])
                  (Map.toUnfoldable inv :: Array (Tuple String _))
              )

        -- Sub-category select
        , (Tuple <$> inventoryValue <*> selMainValue) <#~> \(Tuple inv main) ->
            let subs = fromMaybe Map.empty (Map.lookup main inv)
            in D.select
              [ DL.change_ \e ->
                  for_ (target e >>= HSelect.fromEventTarget) \el -> do
                    v <- HSelect.value el
                    setSelSub v
                    let firstItem = fromMaybe "" do
                          items <- Map.lookup v subs
                          Array.head items
                    setSelItem firstItem
              ]
              ( map (\(Tuple s _) -> D.option [ DA.value_ s ] [ text_ s ])
                  (Map.toUnfoldable subs :: Array (Tuple String _))
              )

        -- Item select
        , (Tuple <$> (Tuple <$> inventoryValue <*> selMainValue) <*> selSubValue)
            <#~> \(Tuple (Tuple inv main) sub) ->
              let items = fromMaybe [] do
                    subs  <- Map.lookup main inv
                    Map.lookup sub subs
              in D.select
                [ DL.change_ \e ->
                    for_ (target e >>= HSelect.fromEventTarget) \el -> do
                      v <- HSelect.value el
                      setSelItem v
                ]
                ( map (\i -> D.option [ DA.value_ i ] [ text_ i ]) items )

        , D.button
            [ DL.runOn DL.click $
                ( \main sub item n -> do
                    cd <- loadCountData
                    case applyDelta vid main sub item n cd of
                      Nothing  -> do
                        showErrorOverlay
                        setStatus ("Cannot subtract " <> show n <> " from " <> item)
                      Just cd' -> do
                        updateCountData cd'
                        setStatus ("Added " <> show n <> " \x00d7 " <> item)
                ) <$> selMainValue <*> selSubValue <*> selItemValue <*> countInputValue
            ]
            [ text_ "+" ]

        , D.button
            [ DL.runOn DL.click $
                ( \main sub item n -> do
                    cd <- loadCountData
                    case applyDelta vid main sub item (negate n) cd of
                      Nothing  -> do
                        showErrorOverlay
                        setStatus ("Cannot subtract " <> show n <> " from " <> item)
                      Just cd' -> do
                        updateCountData cd'
                        setStatus ("Removed " <> show n <> " \x00d7 " <> item)
                ) <$> selMainValue <*> selSubValue <*> selItemValue <*> countInputValue
            ]
            [ text_ "-" ]

        , D.input
            [ DA.xtype_ "number"
            , DA.id_ "count-input"
            , DA.value_ "1"
            , DA.min_ "1"
            , DA.step_ "1"
            , DL.change_ \e ->
                for_ (target e >>= HInput.fromEventTarget) \el -> do
                  v <- HInput.value el
                  case (hush (readJSON v) :: Maybe Int) of
                    Just n  -> setCountInput n
                    Nothing -> pure unit
            ]
            []

        , D.button
            [ DL.click_ \_ -> updateCountData Map.empty ]
            [ text_ "Clear Count" ]

        , D.button
            [ DL.click_ \_ -> do
                for_ [ keyCountData, keyListName, keySourceHash
                      , keyVisitorId, keyImportedHashes
                      ] removeItem
                reload
            ]
            [ text_ "Clear ALL" ]

        , D.label [ DA.klass_ "file-label", DA.for_ "import-inventory" ]
            [ text_ "Load Inventory" ]
        , D.input
            [ DA.xtype_ "file"
            , DA.id_ "import-inventory"
            , DA.klass_ "hidden"
            , DA.accept_ ".json"
            , DL.change_ \e -> do
                let mInput = target e >>= HInput.fromEventTarget
                for_ mInput \fi -> do
                  mFiles <- HInput.files fi
                  for_ mFiles \lst ->
                    for_ (FileList.item 0 lst) \f ->
                      launchAff_ do
                        { content, hash } <- readFile f
                        liftEffect case readInventory content of
                          Left _    -> showErrorOverlay
                          Right inv -> do
                            setItem keySourceHash hash
                            setInventory inv
            ]
            []
        ]

    -- Count table
    , countDataValue <#~> \cd ->
        D.table [ DA.klass_ "count-table" ]
          [ D.colgroup_
              [ D.col [ DA.klass_ "col-count" ] []
              , D.col [ DA.klass_ "col-diff"  ] []
              , D.col [ DA.klass_ "col-item"  ] []
              , D.col [ DA.klass_ "col-sub"   ] []
              , D.col [ DA.klass_ "col-main"  ] []
              ]
          , D.thead_
              [ D.tr_
                  [ D.th_ [ text_ "#"        ]
                  , D.th_ [ text_ "+/-"       ]
                  , D.th_ [ text_ "Item"      ]
                  , D.th_ [ text_ "Type"      ]
                  , D.th_ [ text_ "Category"  ]
                  ]
              ]
          , D.tbody_ (buildRows vid cd updateCountData)
          ]

    -- Status bar
    , D.div [ DA.id_ "status-message" ] [ text statusValue ]
    ]

-- ---------------------------------------------------------------------------
-- Table rows
-- ---------------------------------------------------------------------------

buildRows
  :: VisitorId
  -> CountData
  -> (CountData -> Effect Unit)
  -> Array Nut
buildRows vid cd updateCD = do
  Tuple main subs  <- Map.toUnfoldable cd
  Tuple sub  items <- Map.toUnfoldable subs
  Tuple item idata <- Map.toUnfoldable items
  let
    lastNote   = Array.last idata.notes
    diffText   = fromMaybe "" (map (show <<< _.delta) lastNote)
    diffClass  = case lastNote of
      Nothing -> ""
      Just n  -> if n.visitorId == vid then "diff-own" else "diff-imported"
    colorClass = case lastNote of
      Nothing -> ""
      Just n  -> if n.delta < 0 then "diff-neg" else "diff-pos"
  pure $ D.tr
    [ DL.click_ \_ -> pure unit ]
    [ D.td_ [ text_ (show idata.count) ]
    , D.td [ DA.klass_ (diffClass <> " " <> colorClass) ] [ text_ diffText ]
    , D.td_ [ text_ item ]
    , D.td_ [ text_ sub  ]
    , D.td_ [ text_ main ]
    ]