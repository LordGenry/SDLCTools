{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE RecordWildCards   #-}
module Main where

import           Data.Aeson
import qualified Data.ByteString.Char8 as B8
import qualified Data.ByteString.Lazy.Char8 as BL8
import           Data.Maybe (catMaybes)
import           Data.Monoid ((<>))
import           Data.List.Utils (replace)
import qualified Data.Text as T
import           Network.HTTP.Simple
import           Options.Applicative as OA
import           System.FilePath.Posix

import           Types
import           Extract
import           Report


data CliOptions = MkCliOptions {
                  relPath :: String
                , apiToken :: String
                } deriving (Show)

optionParser :: OA.Parser CliOptions
optionParser =
  MkCliOptions
        <$> strOption (
              long "relativePath"
              <> short 'p'
              <> (help "Relative Path to Query and Token Directory"))
        <*> strOption (
              long "Api Token"
              <> short 't'
              <> (help "GitHub APi Token"))

-- | Parse command line options
parseCliArgs :: IO CliOptions
parseCliArgs = customExecParser (prefs showHelpOnError) (info optionParser fullDesc)


main :: IO ()
main = do
  (MkCliOptions {..}) <- parseCliArgs
  queryTemplate <- filter (\c -> c /= '\n') <$> readFile (relPath </> "queryPullRequestAll")
  let loop :: Int -> T.Text -> [PRAnalysis] -> IO ()
      loop n cursor acc = do
        putStrLn ("n = " ++ show n)
        let query = replace "###" (T.unpack cursor) queryTemplate
        putStrLn query
        respAllCommits  <- runQuery apiToken query
        BL8.appendFile "resp.json" respAllCommits
        let parserPrs      = eitherDecode respAllCommits :: Either String GHResponse
        case parserPrs of
          Right (GHResponse (PageInfo{..}, prs)) -> do
            if hasNextPage
              then
                loop (n+1) ("\\\"" <> endCursor <> "\\\"" ) ((catMaybes $ mkPRAnalysis <$> prs) <> acc)
              else
                do
                  makeReport "PRAnalysis.csv" $ (catMaybes $ mkPRAnalysis <$> prs) <> acc
                  putStrLn $ "OK : made " <> show n <> " calls to Github"
          Left e  -> do
            makeReport "PRAnalysis.csv" acc
            putStrLn $ "oops error occured" <> e

  loop 0 "" []

runQuery :: String -> String -> IO (BL8.ByteString)
runQuery token query = do
  let authorization = "token " ++ token
  req' <- parseRequest "POST https://api.github.com/graphql"
  let req = setRequestHeaders [ ("User-Agent", "Firefox")
                              , ("Authorization", B8.pack authorization)
                              , ("Content-Type", "application/json")
                              ]
          . setRequestBodyLBS (BL8.pack query) $ req'

  response <- httpLBS req
  putStrLn $ "The status code was: " ++
              show (getResponseStatusCode response)
  let responseBody = getResponseBody response
  return responseBody

