{-# LANGUAGE DeriveAnyClass       #-}
{-# LANGUAGE DeriveGeneric        #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE RecordWildCards      #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE BangPatterns         #-}

module GH.Issue where


import Debug.Trace (trace)

import            Control.Concurrent

import            Control.Monad
import            Control.Applicative
import            GHC.Generics
import            Data.Aeson
import            Data.Aeson.Types
import qualified  Data.List as L
import qualified  Data.Map.Strict as M
import            Data.Maybe (catMaybes)
import qualified  Data.Text as T
import            Data.Vector      (toList)

import            Data.Time.Calendar
import            Data.Time.Clock
import            Data.Time.Clock.POSIX
import            Data.Time.Format

import            GH.Config
import            GH.Epic
import            GH.Parser
import            GH.Queries
import            GH.StateTransition
import            GH.Types




getIssues :: Config -> IO [(String, [Issue])]
getIssues MkConfig{..} = do
  issues <- mapM (\repo -> getIssuesForOneRepo cfg_gh_key cfg_zh_key repo) cfg_Repos
  return issues


getIssuesForOneRepo :: String -> String -> (String, String, Int) -> IO (String, [Issue])
getIssuesForOneRepo ghKey zhKey (user, repo, repoId) = do
  issues <- getGHIssuesForRepo user repo repoId
  let issues1 = L.map (\(r, ghi, ghEvts, zhi, zhEvts) -> MkIssue ghi zhi ghEvts zhEvts (T.pack r) STIllegalStateTransitions) issues
  -- get rid of PR's
  let issues2 = L.filter (not . ghiIsPR . iGHIssue) issues1
  let issues3 = L.map computeStateTransitions issues2

  -- get Issue -> Epic Map
  epicMap <- makeEpicMap zhKey repoId

  -- update issues with Epic parent.
  let issues4 = L.map (\issue@MkIssue{..} -> let
                          p = M.lookup (ghiNumber iGHIssue) epicMap
                          in issue { iZHIssue = iZHIssue {zhiParentEpic = p}})
                      issues3

  -- update issues with chidren
  let invertedEpicMap = invertMap epicMap
  let issues5 = L.map (\issue@MkIssue{..} ->
                          case M.lookup (ghiNumber iGHIssue) invertedEpicMap of
                          Just children -> issue { iZHIssue = iZHIssue {zhiChildren = children}}
                          Nothing -> issue
                      )
                      issues4

  return (repo, issues5)
  where
  getGHIssuesForRepo user repo repoId = do
    jsons <- getAllIssuesFromGHRepo ghKey user repo
    let ghIssues = L.concat $ L.map (\json ->
                    case eitherDecode json of
                      Right issues -> issues
                      Left e -> error e) jsons
    mapM proc ghIssues
    where
    proc ghIssue = do
      print ("getting data for: ", ghiNumber ghIssue)
      -- poor man rate control
      threadDelay 150000

      zhIssue <- getZHIssueForRepo repo repoId ghIssue
      zhIssueEvents <- getZHIssueEventsForRepo repo repoId ghIssue
      ghIssueEvents <- getGHIssueEventsForRepo user repo ghIssue

      return (repo, ghIssue, ghIssueEvents, zhIssue, zhIssueEvents)

  getGHIssueEventsForRepo user repo ghIssue@MkGHIssue{..} = do
    json <- getIssueEventsFromGHRepo ghKey user repo ghiNumber
    let (ghEvtsE :: Either String [Maybe GHIssueEvent]) = eitherDecode json
    case ghEvtsE of
      Right ghEvts -> return $ catMaybes ghEvts
      Left e -> fail e

  getZHIssueForRepo repo repoId ghIssue@MkGHIssue{..} = do
    json <- getSingleIssueFromZHRepo zhKey repoId ghiNumber
--    print "====================="
--    print json

    let (zhIssueE :: Either String ZHIssue) = eitherDecode json
    case zhIssueE of
      Right zhIssue -> return zhIssue
      Left e -> fail e

  getZHIssueEventsForRepo repo repoId ghIssue@MkGHIssue{..} = do
    json <- getSingleIssueEventsFromZHRepo zhKey repoId ghiNumber
    let (zhEvtsE :: Either String [Maybe ZHIssueEvent]) = eitherDecode json
    case zhEvtsE of
      Right zhEvts -> return $ catMaybes zhEvts
      Left e -> fail e



computeStateTransitions :: Issue -> Issue
computeStateTransitions issue@MkIssue{..} =
  issue {iStateTransitions = st}
  where
  MkGHIssue {..} = iGHIssue
  st = getStateTransitions ghiCreationTime $ getStateEvents iGHIssueEvents iZHIssueEvents


invertMap :: M.Map Int Int -> M.Map Int [Int]
invertMap m =
  M.foldrWithKey (\k a acc -> M.insertWith (++) a [k] acc) M.empty m

-- foldrWithKey :: (k -> a -> b -> b) -> b -> Map k a -> b

--insertWithKey :: Ord k => (k -> a -> a -> a) -> k -> a -> Map k a -> Map k a Source #
--insertWith :: Ord k => (a -> a -> a) -> k -> a -> Map k a -> Map k a Source #







