{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BangPatterns #-}


module Main where

--import Lib

import Control.Applicative

import Data.Ratio

import Data.Decimal
import Debug.Trace(trace)
import Control.Monad.State
import Control.Monad
import Data.Monoid


import qualified  Data.Map.Strict as M
import qualified  Data.Set as S
import qualified  Data.List as L


--import qualified  Data.ByteString.Lazy as LBS
--import            Data.Time.Clock


import            Gtsim.Simulator

import            Meas.Dev.Types
import            Meas.Dev.Extractor
import            Meas.Misc
import            Meas.Dev.Report.Report

import            Gtsim.Types
import qualified  Gtsim.Invariants as I

import            Planning.Loader as LO
import            Planning.Processing

import System.IO

main :: IO ()
main = do
  (MkOptions {..}) <- parseCliArgs
  run optAuth 42 100
 -- zz' <- LO.zz 50000
  --mapM LO.z $ L.take 10 $ L.repeat 1
 -- print zz'
--  withFile "beta.txt" WriteMode $ \h -> do
--              hPutStrLn h "x"
--              mapM_ (hPutStrLn h . show) zz'
  --withFile :: FilePath -> IOMode -> (Handle -> IO r) -> IO r



run :: String -> Int -> Int -> IO ()
run authorization seed nbSims = do
  res <- getAllNoHistory authorization
          [
           -- ("CBR",  "Type:{User Story} #Bug State: Backlog #Selected #Planning sort by: {issue id} asc")
            ("CDEC", "Type:{User Story} #Bug State: Backlog #Selected #Planning sort by: {issue id} asc")
          -- ("CHW", "Type:{User Story} #Bug State: Backlog #Selected #Planning sort by: {issue id} asc")

--         ("DDW", "issue id: DDW-10")
--         ("DDW", "Type:Task #{User Story} #Bug sort by: {issue id} asc")

         --   ("DEVOPS", "Type:Task  #Bug sort by: {issue id} asc")
         --   , ("TSD", "Type:Task #{User Story} #Bug sort by: {issue id} asc")
         --   , ("PB", "Type:Task #{User Story} #Bug sort by: {issue id} asc")
         --   , ("DDW", "Type:Task #{User Story} #Bug sort by: {issue id} asc")
         --   , ("CDEC", "Type:Task #{User Story} #Bug sort by: {issue id} asc")
         --   , ("CBR", "Type:Task #{User Story} #Bug sort by: {issue id} asc")
         --   , ("CHW", "Type:Task #{User Story} #Bug sort by: {issue id} asc")
         --   , ("CO", "Type:Task #{User Story} #Bug sort by: {issue id} asc")
          ]

  --
  let issues = concat $ map (\(_, _, issue) -> issue) res

  --mapM print issues


  putStrLn "simulation"
  let (simState, problemDefinition) = LO.initialize iohkResources issues

  let ts = (pdTasksPerResource problemDefinition)

  putStrLn $ "Nb of issues: " ++ (show $ M.size $ pdTasks problemDefinition)

--  print $ pdTasks problemDefinition
  let simRes = runSimulations
                --I.simStateInv I.finalSimStateAdditionalInv
                (const []) (\_ _ -> [])
                problemDefinition 1 simState
                getFinalEndTime stats
                seed nbSims

  putStrLn "results"
  --mapM print simRes
  print simRes
  return ()




{- Result = (Mean = 0.34, St. Dev = 0.115, Variance = 0.005) -}

stats :: [Rational] -> (Float, Float)
stats xs =
  (avg, stdDev)
  where
  xs' = map fromRational xs
  length' = fromIntegral . length
  avg :: Float
  avg = (/) <$> sum <*> length' $ xs'
  stdDev :: Float
  stdDev = sqrt $ summedElements / lengthX
  lengthX = length' xs'
  summedElements = sum (map (\x -> (x - avg) ^ 2) xs')

