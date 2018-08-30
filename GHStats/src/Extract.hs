{-# Language BangPatterns         #-}
{-# LANGUAGE RecordWildCards      #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE ScopedTypeVariables  #-}



module Extract where

import qualified Data.List as L
import qualified Data.Text as T

import Types


-- | given a PullRequest returns the authored date of the earliest commit.
getFirstCommitTime :: PullRequest -> Date
getFirstCommitTime PullRequest{..} = cAuthoredDate . head $ prCommits

-- | given a PullRequest returns the authored date of the latest commit.
getLastCommitTime :: PullRequest -> Date
getLastCommitTime PullRequest{..} = cAuthoredDate . last $ prCommits

-- | Splits commits between those created before the PR creation and those created after the PR creation
splitCommits :: PullRequest -> ([Commit], [Commit])
splitCommits PullRequest{..} = L.partition (\c -> cAuthoredDate c <= prCreatedAt) prCommits

-- partition :: (a -> Bool) -> [a] -> ([a], [a])


-- | given the latest commit time and a PR containing the first commit
-- date, mkPRAnalysis returns a PRAnalysis.
mkPRAnalysis :: PullRequest -> PRAnalysis
mkPRAnalysis pr@PullRequest{..} =
  let !prNum            = prNumber
      !firstCommitTime  = getFirstCommitTime pr
      !latestCommitTime = getLastCommitTime pr
      !prClosingDate    =
        if (prMergedAt == Nothing)
          then prClosedAt
        else prMergedAt
      devReviewCommits = splitCommits pr
  in PRAnalysis prNum firstCommitTime prCreatedAt latestCommitTime prClosingDate devReviewCommits prComments













