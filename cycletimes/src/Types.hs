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
import qualified Data.Text as T
import           Data.Vector      (toList)

import            Data.Time.Calendar
import            Data.Time.Clock
import            Data.Time.Clock.POSIX
import            Data.Time.Format


toUTCTime :: Int -> UTCTime
toUTCTime n = posixSecondsToUTCTime (fromIntegral $ n `div` 1000)


data Issue = MkIssue
  { iGHIssue  :: GHIssue
  , iZHIssue  :: ZHIssue
  , iGHIssueEvents :: [GHIssueEvent]
  , iZHIssueEvents :: [ZHIssueEvent]
  , iRepoName :: T.Text
  }
  deriving (Show, Eq, Ord)



data GHUser = MkGHUser
  { ghuUser     :: T.Text
  , ghuUserId   :: Int
  }
  deriving (Show, Eq, Ord)

defGHUser :: GHUser
defGHUser = MkGHUser "" 0

data GHIssue = MkGHIssue
  { ghiId               :: Int
  , ghiNumber           :: Int
  , ghiTitle            :: T.Text
  , ghiUser             :: GHUser
  , ghiCreationTime     :: UTCTime
  , ghiMainAssignee     :: Maybe GHUser
  , ghiAssignees        :: [GHUser]
  , ghiUrl              :: T.Text
  }
  deriving (Show, Eq, Ord)

data ZHIssue = MkZHIssue
  { zhiState            :: State
  , zhiIsEpic           :: Bool
  }
  deriving (Show, Eq, Ord)



data GHIssueEvent =
  GHEvtCloseEvent TimeStamp
  |GHEvtReOpenEvent TimeStamp
--  |GHEvtOther
  deriving (Show, Eq, Ord)



data ZHIssueEvent =
  ZHEvtTransferState State State TimeStamp
--  | ZHEvtSetState State TimeStamp
--  | ZHNoEvent
  deriving (Show, Eq, Ord)

data StateEvent = StateEvent State State TimeStamp
  deriving (Eq, Show, Generic)


data State =
  Backlog
  |InProgress
  |InReview
  |Done
  deriving (Eq, Show, Generic, Ord)

type UserId = Int
type TimeStamp = UTCTime

--parseEvents :: Value -> Parser [Event]
--parseEvents (Array arr) = do
--  forM (toList arr) parseJSON :: Parser [Event]

nameToState :: T.Text -> State
nameToState "New Issues"     = Backlog
nameToState "In Progress"    = InProgress
nameToState "Review/QA"      = InReview
nameToState "Closed"         = Done
nameToState "Epics"          = Backlog
nameToState "Proposed"       = Backlog
nameToState "Accepted"       = Backlog
nameToState e = error (T.unpack e)



-- J-C view on events
{-
data Events =
  Created TimeStamp    -- ^ time the issue is created, time associated with Backlog state, from GH
  |Transition State State TimeStamp  -- ^ state transition, from ZenHub
  |Closed TimeStamp  -- ^ time when the issue is closed, from GH
  |ReOpen TimeStamp  -- ^ time when the issue is re-opened, from GH



data Events =
  Transition State State TimeStamp  -- ^ state transition, from ZenHub



data StateTransitions =
  STBacklog UTCTime
  |STInProgress UTCTime UTCTime UTCTime
  |STInReview UTCTime UTCTime UTCTime UTCTime
  |STDone UTCTime UTCTime UTCTime UTCTime UTCTime
  |STIllegalStateTransitions
  deriving (Eq, Show)
-}
{-
Given a list of such event, the goal is to find a algo that will produce a set S of
forward-only state transactions: Backlog -> InProgress -> InReview -> Done.
with some conditions:

Backlog time always = creation time

If a Done state is in the set S, it has the highest time .
Beware of backwards transitions from Done to InProgress, Review.
Transition from Done to Backlog are problematic,

-}



