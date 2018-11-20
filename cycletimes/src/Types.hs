{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE RecordWildCards   #-}
module Types where

import           Control.Monad
import           Control.Applicative
import           GHC.Generics
import           Data.Aeson
import           Data.Aeson.Types
import           Data.Text
import           Data.Vector      (toList)

import            Data.Time.Calendar
import            Data.Time.Clock
import            Data.Time.Clock.POSIX
import            Data.Time.Format


toUTCTime :: Int -> UTCTime
toUTCTime n = posixSecondsToUTCTime (fromIntegral $ n `div` 1000)


data Event =
  TransferState State State TimeStamp UserId
  | SetState State TimeStamp UserId
  | NotImportant
  deriving (Eq, Show, Generic)

instance FromJSON Event where
  parseJSON = withObject "Event" $ \o -> do
    eventType <- o .: "type" :: Parser Text
    case eventType of
      "transferIssue" -> do
        timeStamp <- toUTCTime <$> (o .: "created_at" :: Parser Int)

        let transferState  = do
              fromPipeLine <-  o .: "from_pipeline"
              fromState <- nameToState <$> (fromPipeLine .: "name" :: Parser Text)
              toPipeLine <-  o .: "to_pipeline"
              toState <- nameToState <$> (toPipeLine .: "name" :: Parser Text)
              pure $ TransferState fromState toState (toUTCTime 1) 1

        let setState  = do
              toPipeLine <-  o .: "to_pipeline"
              toState <- nameToState <$> (toPipeLine .: "name" :: Parser Text)
              pure $ SetState toState (toUTCTime 1) 1

        transferState <|> setState

      _ -> pure NotImportant

data State =
  Backlog
  |InProgress
  |InReview
  |Done
  deriving (Eq, Show, Generic)

type UserId = Int
type TimeStamp = UTCTime

parseEvents :: Value -> Parser [Event]
parseEvents (Array arr) = do
  forM (toList arr) parseJSON :: Parser [Event]

nameToState :: Text -> State
nameToState "New Issues"  = Backlog
nameToState "In Progress" = InProgress
nameToState "Review/QA"   = InReview
nameToState "Closed"      = Done
