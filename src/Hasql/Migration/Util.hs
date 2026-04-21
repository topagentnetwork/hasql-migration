-- |
-- Module      : Hasql.Migration.Util
-- Copyright   : (c) 2016 Timo von Holtz <tvh@tvholtz.de>,
--               (c) 2014-2016 Andreas Meingast <ameingast@gmail.com>
--
-- License     : BSD-style
-- Maintainer  : tvh@tvholtz.de
-- Stability   : experimental
-- Portability : GHC
--
-- A collection of utilites for database migrations.
module Hasql.Migration.Util
  ( existsTable,
  )
where

import Data.Text (Text)
import Hasql.Decoders qualified as Decoders
import Hasql.Encoders qualified as Encoders
import Hasql.Statement (unpreparable)
import Hasql.Transaction (Transaction, statement)

-- | Checks if the table with the given name exists in the database.
existsTable :: Text -> Transaction Bool
existsTable table =
  fmap (not . null) $ statement table q
  where
    q = unpreparable sql (Encoders.param (Encoders.nonNullable Encoders.text)) (Decoders.rowList (Decoders.column (Decoders.nullable Decoders.int8)))
    sql = "select relname from pg_class where relname = $1"
