{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE DeriveGeneric        #-}
{-# LANGUAGE DeriveAnyClass       #-}
{-# LANGUAGE RecordWildCards      #-}
{-# LANGUAGE ScopedTypeVariables  #-}


module PR.Types where

import            Control.Monad
import            Data.Aeson
import            Data.Aeson.Types
import            Data.Text
import            Data.Time.Clock
import            Data.Time.Format
import            GHC.Exts (sortWith)
import            GHC.Generics

import qualified Meas.Dev.Types as M

newtype GHResponse = GHResponse ( PageInfo , [PullRequest] )
  deriving ( Show )

instance FromJSON GHResponse where
  parseJSON = parseResponse

data PullRequest = PullRequest {
                   prId           :: Id
                 , prNumber       :: Int
                 , prTitle        :: Title
                 , prAuthor       :: Author
                 , prCreatedAt    :: Date
                 , prState        :: PRState
                 , prClosed       :: Bool
                 , prClosedAt     :: Maybe Date
                 , prMerged       :: Bool
                 , prMergedAt     :: Maybe Date
                 , prCommits      :: [Commit]
                 , prComments     :: [Comment]
                 , prSourceBranch :: BranchName
                 , prTargetBranch :: BranchName
                 , prRepo         :: String
                 } deriving ( Show, Eq, Generic)

instance FromJSON PullRequest where
  parseJSON = parsePullRequest

data Commit = Commit {
              cId            :: Id
            , cCommittedDate :: Date
            , cAuthoredDate  :: Date
            , cMessage       :: Message
            , cAuthor        :: Maybe Name
            , cAuthorEmail   :: Maybe Email
            } deriving ( Show, Eq, Generic)

instance FromJSON Commit where
  parseJSON = parseCommit

data Comment = Comment {
               coId        :: Id
             , coBodyText  :: BodyText
             , coCreatedAt :: Date
             , coAuthor    :: Author
             } deriving ( Show, Eq, Generic)

instance FromJSON Comment where
  parseJSON = parseComment

data Author = Author {
              auName :: Maybe Name
            } deriving ( Show, Eq, Generic)

instance FromJSON Author where
  parseJSON = withObject "Author" $ \o -> do
    auName <- o .:? "name"
    return Author{..}

data PRState = OPEN | CLOSED | MERGED
  deriving ( Show, Eq, Generic, FromJSON)

type Title          = Text
type Id             = Text
type Date           = UTCTime
type Name           = Text
type Message        = Text
type BodyText       = Text
type YtIssueId      = Text
type BranchName     = Text
type Cursor         = Text
type Email          = Text
type YtAuthorization = String

-- | Pull Request Analysis
data PRAnalysis = PRAnalysis {
                  paPRNumber          :: Int
                , paYTIssueId         :: Maybe YtIssueId
                , paFirstCommitTime   :: Date
                , paPRCreationTime    :: Date
                , paLatestCommitTime  :: Date
                , paPRClosingTime     :: Maybe Date
                , paWasMerged         :: Bool
                , paPrAuthor          :: Maybe Name
                , paDevReviewCommits  :: ([Commit], [Commit])
                , paComments          :: [Comment]
                , paSourceBranch      :: Text
                , paTargetBranch      :: Text
                , paYtIssueIdPresence :: Bool
                , paYtType            :: Maybe M.TypeValue
                , paYtState           :: Maybe M.StateValue
                , paRepo              :: String
                } deriving ( Show, Eq, Generic)

-- | Pull Request Commit Details
data PRCDetails = PRCDetails {
                 pcdPRNumber       :: Int
               , pcdPRAuthor       :: Maybe Name
               , pcdCoAuthoredDate :: Date
               , pcdCoAuthor       :: Maybe Name
               , pcdCoAuthorEmail  :: Maybe Email
               , pcdPRYTIssueId    :: Maybe YtIssueId
               , pcdCommitYTId     :: Maybe YtIssueId
               , pcdCommitId       :: Text
               } deriving ( Show, Eq, Generic)

data PageInfo = PageInfo {
                endCursor       :: Cursor
              , hasNextPage     :: Bool
              , hasPreviousPage :: Bool
              , startCursor     :: Cursor
              } deriving ( Show, Eq, Generic)

instance FromJSON PageInfo where
  parseJSON = withObject "PageInfo" $ \pageInfoNode -> do
    endCursor       <- pageInfoNode .: "endCursor"
    hasNextPage     <- pageInfoNode .: "hasNextPage"
    hasPreviousPage <- pageInfoNode .: "hasPreviousPage"
    startCursor     <- pageInfoNode .: "startCursor"
    return PageInfo{..}

data YtInfo = YtInfo {
              yiYtTypeVal     :: M.TypeValue
            , yiYtStateStatus :: M.StateValue
            } deriving (Show, Eq, Generic)

parseResponse :: Value -> Parser GHResponse
parseResponse = withObject "All PullRequests" $ \o -> do
  data_           <- o               .: "data"
  organisation    <- data_           .: "organization"
  repository      <- organisation    .: "repository"
  allPullRequests <- repository      .: "pullRequests"
  pageInfo        <- allPullRequests .: "pageInfo"
  prNodes         <- allPullRequests .: "nodes"
  pullRequests    <- forM prNodes parsePullRequest
  return $ GHResponse (pageInfo, pullRequests)


parsePullRequest :: Value -> Parser PullRequest
parsePullRequest = withObject "PullRequest" $ \pullRequest -> do
  prId              <- pullRequest  .: "id"
  prNumber          <- pullRequest  .: "number"
  prTitle           <- pullRequest  .: "title"
  prCreatedAt       <- fmap parseDate $ pullRequest  .: "createdAt"
  prState           <- pullRequest  .: "state"
  prClosed          <- pullRequest  .: "closed"
  prClosedAt        <- pullRequest  .: "closedAt"
  prMerged          <- pullRequest  .: "merged"
  prMergedAt        <- pullRequest  .: "mergedAt"
  prAuthor          <- pullRequest  .: "author"
  allCommits        <- pullRequest  .: "commits"
  commitNodes       <- allCommits   .: "nodes"
  unsortedPrCommits <- forM commitNodes parseCommit
  let prCommits =   sortWith cAuthoredDate unsortedPrCommits
  allComments       <- pullRequest  .: "comments"
  commentNodes      <- allComments  .: "nodes"
  prComments        <- forM commentNodes parseComment
  prSourceBranch    <- pullRequest  .: "headRefName"
  prTargetBranch    <- pullRequest  .: "baseRefName"
  let prRepo = ""
  return PullRequest{..}

parseCommit :: Value -> Parser Commit
parseCommit = withObject "Commit" $ \commitNode -> do
  commit         <- commitNode    .: "commit"
  cId            <- commit        .: "id"
  cCommittedDate <- commit        .: "committedDate"
  cAuthoredDate  <- commit        .: "authoredDate"
  cMessage       <- commit        .: "message"
  cAuthorObject  <- commit        .: "author"
  cAuthor        <- cAuthorObject .: "name"
  cAuthorEmail   <- cAuthorObject .: "email"
  return Commit{..}

parseComment :: Value -> Parser Comment
parseComment = withObject "Comment" $ \comment -> do
  coId        <- comment .: "id"
  coBodyText  <- comment .: "bodyText"
  coCreatedAt <- comment .: "createdAt"
  coAuthor    <- comment .: "author"
  return Comment{..}

parseDate :: String -> Date
parseDate = parseTimeOrError True defaultTimeLocale (iso8601DateFormat (Just "%H:%M:%SZ"))
