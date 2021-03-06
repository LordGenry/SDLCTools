{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}


{-# LANGUAGE TemplateHaskell #-}

module Meas.Misc
(
  defUTCTime
  , intToDateText
  , previousSecond
  , toUTCTime
  , utcTimeToStdDateText

  , parseCliArgs

  , Options (..)
)
where

-- import Debug.Trace (trace)

import            Data.Monoid
import qualified  Data.Text as T
import            Data.Time.Calendar
import            Data.Time.Clock
import            Data.Time.Clock.POSIX
import            Data.Time.Format

import            Options.Applicative

defUTCTime :: UTCTime
defUTCTime = UTCTime (ModifiedJulianDay 0) 0


toUTCTime :: Int -> UTCTime
toUTCTime n = posixSecondsToUTCTime (fromIntegral $ n `div` 1000)

previousSecond :: UTCTime -> UTCTime
previousSecond t = addUTCTime  (-1) t

intToDateText :: UTCTime -> T.Text
intToDateText t = T.pack $ formatTime defaultTimeLocale  "%Y%m%d" t


utcTimeToStdDateText :: UTCTime -> T.Text
utcTimeToStdDateText t = T.pack $ formatTime defaultTimeLocale  (iso8601DateFormat Nothing) t



data Options = MkOptions {
  optConfigFile :: String
  }
  deriving (Show)

optionParser :: Parser Options
optionParser =
  MkOptions
        <$> strOption (
              long "config"
              <> value "config.yml"
              <> short 'c'
              <> (help "Config file name"))

-- | Parse command line options
parseCliArgs :: IO Options
parseCliArgs = customExecParser (prefs showHelpOnError) (info optionParser fullDesc)




