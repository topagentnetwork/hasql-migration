# hasql-migration

PostgreSQL schema migrations for [hasql]. Tracks executed scripts by
filename and MD5 checksum so changes to already-applied migrations are
detected at runtime.

> **Fork notice.** This is a fork of [tvh/hasql-migration], which is
> itself a port of [postgresql-simple-migration]. This fork targets
> current toolchains — `hasql >= 1.10`, `hasql-transaction >= 1.2`,
> `crypton >= 1.0`, GHC 9.12, and a Nix flake based dev shell — and
> switches the `schema_migrations` table to `text` columns. Upstream has
> not been updated recently, so breaking changes here are not coordinated
> with it.

[hasql]: https://hackage.haskell.org/package/hasql
[tvh/hasql-migration]: https://github.com/tvh/hasql-migration
[postgresql-simple-migration]: https://github.com/ameingast/postgresql-simple-migration

## Why

Database migrations should be version-controlled, reproducible, and checked
against what has actually been applied in production. This library:

- Executes each SQL script exactly once, in alphabetical order.
- Records an MD5 checksum of every script so edits to already-applied
  migrations fail loudly instead of silently diverging.
- Records an `executed_at` timestamp so you can audit when each change
  landed.
- Supports a validation mode for verifying migration state before the
  application boots.

## Requirements

- GHC 9.12 (the flake pins `ghc912`; other recent GHCs should also work).
- `hasql >= 1.10`
- `hasql-transaction >= 1.2`
- PostgreSQL for running migrations and tests.

Migrations are run inside a `Hasql.Transaction.Transaction`, so you compose
them with the rest of your transactional code.

## Usage

The core API lives in `Hasql.Migration`:

```haskell
import Hasql.Connection (acquire)
import qualified Hasql.Connection.Settings as Settings
import Hasql.Migration
  ( MigrationCommand (..)
  , MigrationError
  , loadMigrationsFromDirectory
  , runMigration
  )
import Hasql.Transaction (Transaction)
import Hasql.Transaction.Sessions (IsolationLevel (..), Mode (..), transaction)
import qualified Hasql.Session as Session

migrate :: FilePath -> Session.Session (Maybe MigrationError)
migrate dir = do
  scripts <- liftIO (loadMigrationsFromDirectory dir)
  transaction Serializable Write $ do
    runFirstError (MigrationInitialization : scripts)
  where
    runFirstError :: [MigrationCommand] -> Transaction (Maybe MigrationError)
    runFirstError []       = pure Nothing
    runFirstError (c : cs) = runMigration c >>= \case
      Just err -> pure (Just err)
      Nothing  -> runFirstError cs
```

Key entry points:

- `runMigration :: MigrationCommand -> Transaction (Maybe MigrationError)`
  executes a single command. Returns `Nothing` on success.
- `loadMigrationsFromDirectory :: FilePath -> IO [MigrationCommand]`
  reads every non-dotfile from `dir` (alphabetical order) into
  `MigrationScript` commands.
- `loadMigrationFromFile :: ScriptName -> FilePath -> IO MigrationCommand`
  loads a single script under an explicit name.
- `getMigrations :: Transaction [SchemaMigration]` returns the currently
  recorded migrations (filename, checksum, `executed_at`).

`MigrationCommand` values:

- `MigrationInitialization` — creates the `schema_migrations` table if
  missing. Run this first.
- `MigrationScript ScriptName ByteString` — executes a script and records
  its checksum, or verifies the checksum if it has already been applied.
- `MigrationValidation cmd` — dry-run form that reports whether `cmd`
  would succeed without applying any changes.

Possible `MigrationError`s:

- `NotInitialised` — `schema_migrations` is missing.
- `ScriptMissing name` — validation saw a script that has never been run.
- `ScriptChanged name` / `ChecksumMismatch name` — the checksum on disk
  differs from what was recorded when the script was first applied.

### Tracking table

`MigrationInitialization` creates:

```sql
create table if not exists schema_migrations
  ( filename     text not null
  , checksum     text not null
  , executed_at  timestamp without time zone not null default now()
  );
```

The checksum is the base64-encoded MD5 of the script bytes.

## Development

The project ships a Nix flake that provides GHC, cabal, HLS, PostgreSQL,
`just`, and a pre-commit hook running `treefmt` (fourmolu).

```bash
nix develop        # enter the dev shell
just               # list available tasks
```

Entering the dev shell also initializes a local PostgreSQL cluster under
`./db/` and exports `PGHOST`, `PGDATA`, `PGDATABASE=rei`, and
`PG_CONNECTION_STRING` for ad-hoc use.

### Build

```bash
cabal build
```

### Tests

The test suite connects to a database named `test` on the default local
PostgreSQL instance (see `test/Main.hs`). Start Postgres, create the
database, then:

```bash
cabal test
```

## License

BSD-3-Clause. See [License](./License).
