module Handler.Admin.Event where

import           Data.Conduit.Binary (sinkLbs)
import           Data.Time.Clock as Clock
import           Yesod.Form.Bootstrap3 (BootstrapFormLayout (..), renderBootstrap3)

import qualified Data.Text as T

import           Import

getAdminEventR :: Handler Html
getAdminEventR = do
  (formWidget, _formEnctype) <- generateFormPost eventForm
  defaultLayout $ do
    setTitle' "Create Event"
    $(widgetFile "admin/events")

postAdminEventR :: Handler Html
postAdminEventR = do
  ((result, formWidget), _formEnctype) <- runFormPost eventForm
  userId  <- requireAuthId
  case result of
    FormSuccess (EventForm n d dt_start mdt_end fi) -> do
      case parseDatetime dt_start of
        Left _msg -> do
          setMessage "invalid date input"
          redirect $ AdminEventR
        Right dt -> do
          filename <- writeToServer fi
          _ <- runDB $ insert (
            Event n (fmap unTextarea d) filename userId False dt Nothing)

          setMessage "Event saved"
          redirect $ AdminEventR

    FormFailure reasons -> defaultLayout $ do
      setMessage $ toHtml $ unlines reasons
      $(widgetFile "admin/events")
    _ -> defaultLayout $ do
      setMessage "something went wrong"
      redirect $ AdminEventR


parseISO8601 :: Text -> Maybe UTCTime
parseISO8601 = parseTimeM True defaultTimeLocale "%Y-%-m-%-d %H:%M" . unpack

parseDatetime :: Text -> Either FormMessage UTCTime
parseDatetime = maybe (Left MsgInvalidDay) Right . parseISO8601

writeToServer :: FileInfo -> Handler Text
writeToServer file = do
  filename <- runResourceT $ fileSource file $$ sinkLbs
  let path = imageFilePath $ genFileName filename
  liftIO $ fileMove file path
  return $ T.pack $ genFileName filename
  where
    genFileName lbs = "upload-" ++ base64md5 lbs

data EventForm
  = EventForm
  { ef_name :: Text
  , ef_description :: Maybe Textarea
  , ef_eventStartDatetime :: Text
  , ef_eventEndDatetime :: Maybe Text
  , ef_fileInfo :: FileInfo
  }

eventForm :: Form EventForm
eventForm = renderBootstrap3 BootstrapBasicForm $
  EventForm
    <$> areq textField (textSettings "name" "Your Event's name") Nothing
    <*> aopt textareaField (textSettings "description" "Describe your event") Nothing
    <*> areq textField (daySettings "start") Nothing
    <*> aopt textField (daySettings "end") Nothing
    <*> fileAFormReq "Choose an Event Image"
  where
    daySettings t = FieldSettings
          { fsLabel = SomeMessage t
          , fsTooltip = Nothing
          , fsId = Just $ "datetimepicker_" <> t <> "_time"
          , fsName = Nothing
          , fsAttrs =
              [ ("class", "form-control")
              , ("placeholder", "placeholder")
              ]
          }
    textSettings t p = FieldSettings
          { fsLabel = t
          , fsTooltip = Nothing
          , fsId = Nothing
          , fsName = Nothing
          , fsAttrs =
              [ ("class", "form-control")
              , ("placeholder", p)
              ]
          }