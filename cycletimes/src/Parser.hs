{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module Parser
where

import Debug.Trace (trace)
import            Control.Applicative
import            Data.Aeson
import            Data.Aeson.Types (Parser)
import qualified  Data.Text as T

import            Data.Time.Calendar
import            Data.Time.Clock
import            Data.Time.Clock.POSIX
import            Data.Time.Format


import            Types


{-

data GHUser = MkGHUser
  { ghiUser     :: T.Text
    ghiUserId   :: T.Text
  }


data GHIssue = MkGHIssue
  { ghiId               :: Int
  , ghiNumber           :: Int
  , ghiTitle            :: T.Text
  , ghiUser             :: GHUser
  , ghiCreationTime     :: UTCTime
  , ghiMainAssignee     :: GHUser
  , ghiAssignees        :: [GHUser]
  }

data GHIssueEvent =
  GHCloseEvent UTCTime
  |GHReOpenEvent UTCTime

data ZHIssue = MkZHIssue
  { zhiState            :: State
    zhiIsEpic           :: Bool
  }
  deriving (Show, Eq, Ord)

-}

parseUTCTime t = parseTimeOrError  True defaultTimeLocale  "%Y-%m-%dT%H:%M%S%QZ" t


instance {-# OVERLAPS #-} FromJSON (Maybe ZHIssueEvent) where
  parseJSON = withObject "ZHEvent" $ \o -> do
    eventType <- o .: "type" :: Parser T.Text
    case eventType of
      "transferIssue" -> do
        timeStampText <- o .: "created_at" :: Parser T.Text
        let timeStamp = parseUTCTime (T.unpack timeStampText)

        let transferState  = do
              fromPipeLine <-  o .: "from_pipeline"
              fromState <- nameToState <$> (fromPipeLine .: "name" :: Parser T.Text)
              toPipeLine <-  o .: "to_pipeline"
              toState <- nameToState <$> (toPipeLine .: "name" :: Parser T.Text)
              return $ Just $ ZHEvtTransferState fromState toState timeStamp

    --    let setState  = do
    --          toPipeLine <-  o .: "to_pipeline"
    --          toState <- nameToState <$> (toPipeLine .: "name" :: Parser T.Text)
    --          return $ Just $ ZHEvtSetState toState timeStamp

        transferState  -- <|> setState

      _ -> return Nothing -- ZHNoEvent

instance FromJSON ZHIssue where
  parseJSON = withObject "ZH Issue" $ \o -> do
    zhiIsEpic       <- o .: "is_epic"
--    zhiIsEpic       <- fmap (maybe False id) (o .:? "is_epic")
    pipeline        <- o .: "pipeline"
    zhiState        <- fmap nameToState $ pipeline .: "name"
    return $ MkZHIssue {..}

instance {-# OVERLAPS #-} FromJSON (Maybe GHIssueEvent) where
  parseJSON = withObject "event" $ \o -> do
    evt  <- o .: "event" :: Parser T.Text
    timeTxt <- o .: "created_at" :: Parser T.Text
    let time = parseUTCTime (T.unpack timeTxt)

    case evt of
      "closed" -> return $ Just $ GHEvtCloseEvent time
      "reopened" -> return $ Just $ GHEvtReOpenEvent time
      _ -> return Nothing

instance FromJSON GHUser where
  parseJSON = withObject "User" $ \o -> do
    ghuUser  <- o .: "login" :: Parser T.Text
    ghuUserId    <- o .: "id" :: Parser Int
    return $ MkGHUser {..}


instance FromJSON GHIssue where
  parseJSON = withObject "Issue" $ \o -> do
    ghiId           <- o .: "id" :: Parser Int
    ghiNumber       <- o .: "number" :: Parser Int
    ghiTitle        <- o .: "title" :: Parser T.Text
    ghiUser         <- o .: "user" :: Parser GHUser
    creationTime    <- o .: "created_at" :: Parser T.Text
    ghiMainAssignee <- o .: "assignee" :: Parser (Maybe GHUser)
    ghiAssignees    <- o .: "assignees" :: Parser [GHUser]
    ghiUrl          <- o .: "html_url" :: Parser T.Text
    let ghiRepoName = T.empty
    let ghiCreationTime = parseTimeOrError  True defaultTimeLocale "%Y-%m-%dT%TZ" (T.unpack creationTime)
    return $ MkGHIssue {..}











