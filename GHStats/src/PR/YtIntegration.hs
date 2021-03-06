{-# Language BangPatterns         #-}
{-# LANGUAGE RecordWildCards      #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE ScopedTypeVariables  #-}

module PR.YtIntegration where

import qualified  Data.Text as T


import            PR.Types

import            Meas.Dev.Types
import            Meas.Dev.Extractor

getYtInfo :: YtAuthorization -> Maybe YtIssueId -> IO (Maybe YtInfo)
getYtInfo _ Nothing = return Nothing
getYtInfo auth (Just issueId) = do
  putStrLn $ T.unpack issueId
  (tasks, issues) <- getSingleIssue auth (T.unpack issueId)
  case (tasks, issues) of
    ([task], [])  -> return . pure $ YtInfo TaskType  (_yttState task)
    ([], [issue]) -> return . pure $ YtInfo IssueType (_ytiState issue)
    _             -> do putStrLn ("Issue: " ++ T.unpack issueId ++ " not found")
                        return Nothing
