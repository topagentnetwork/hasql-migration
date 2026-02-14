-- |
-- Module      : Main
-- Copyright   : (c) 2014 Andreas Meingast <ameingast@gmail.com>
--               (c) 2016 Timo von Holtz <tvh@tvholtz.de>
--
-- License     : BSD-style
-- Maintainer  : tvh@tvholtz.de
-- Stability   : experimental
-- Portability : GHC
--
-- The test entry-point for hasql-migration.

{-# LANGUAGE OverloadedStrings #-}

module Main
    ( main
    ) where

import Hasql.Connection
import qualified Hasql.Connection.Settings as Settings
import Hasql.MigrationTest
import Test.Hspec (hspec)

main :: IO ()
main = do
    conE <- acquire (Settings.connectionString "dbname=test")
    case conE of
      Right con -> hspec (migrationSpec con)
      Left err -> putStrLn $ show err
