---
name: Move witness gen to librustvoting
overview: Remove `generate_orchard_witnesses_at_historical_height` and its tests from zcash_client_sqlite, and make the minimal set of internals public so the function can be reimplemented in librustvoting.
todos:
  - id: remove-witness-fn
    content: Delete generate_orchard_witnesses_at_historical_height from commitment_tree.rs (function + both test fns + test wrappers in orchard mod)
    status: pending
  - id: remove-walletdb-wrapper
    content: Delete the generate_orchard_witnesses_at_historical_height wrapper method from WalletDb in lib.rs
    status: pending
  - id: update-changelog
    content: Remove the generate_orchard_witnesses_at_historical_height bullet from CHANGELOG.md
    status: pending
  - id: make-from-connection-pub
    content: Change SqliteShardStore::from_connection from pub(crate) to pub
    status: pending
  - id: add-conn-accessor
    content: Add pub fn conn(&self) -> &C on WalletDb
    status: pending
  - id: export-ddl-constants
    content: Change TABLE_ORCHARD_TREE_* constants from pub(super) to pub and ensure they are reachable from outside the crate
    status: pending
  - id: simplify-governance-comment
    content: Update the governance comment block above the impl to reflect only the snapshot query
    status: pending
isProject: false
---

# Move witness generation to librustvoting

## What stays in librustzcash (this repo)

- `get_orchard_notes_at_snapshot` in [zcash_client_sqlite/src/wallet/orchard.rs](zcash_client_sqlite/src/wallet/orchard.rs) — unchanged
- Its `WalletDb` wrapper in [zcash_client_sqlite/src/lib.rs](zcash_client_sqlite/src/lib.rs) lines 2328-2339 — unchanged
- Its test `get_orchard_notes_at_snapshot_boundary_heights` in `orchard.rs` — unchanged

## Removals from this repo

1. `**generate_orchard_witnesses_at_historical_height` function** — delete lines 1143-1299 from [zcash_client_sqlite/src/wallet/commitment_tree.rs](zcash_client_sqlite/src/wallet/commitment_tree.rs)
2. `**WalletDb` wrapper method** — delete lines 2341-2370 from [zcash_client_sqlite/src/lib.rs](zcash_client_sqlite/src/lib.rs)
3. **Two test functions** — delete `witnesses_at_frontier` (lines 1514-1605) and `witnesses_at_frontier_empty_positions` (lines 1607-1664) from `commitment_tree.rs`, plus their `#[test]` wrappers in the `orchard` test module (lines 1387-1395)
4. **CHANGELOG entry** — remove the `generate_orchard_witnesses_at_historical_height` bullet from [zcash_client_sqlite/CHANGELOG.md](zcash_client_sqlite/CHANGELOG.md) line 16-17

## Visibility changes (expose minimal internals)

These are the small changes needed so librustvoting can reimplement the function externally:

1. `**SqliteShardStore::from_connection`** in [zcash_client_sqlite/src/wallet/commitment_tree.rs](zcash_client_sqlite/src/wallet/commitment_tree.rs) line 106 — change `pub(crate)` to `pub`
2. `**WalletDb.conn` accessor** — add a public method on `WalletDb`:

```rust
   pub fn conn(&self) -> &C {
       &self.conn
   }
   

```

   This lets librustvoting call `wallet_db.conn()` to get a `&Connection` without exposing the field directly.
3. **Table DDL constants** in [zcash_client_sqlite/src/wallet/db.rs](zcash_client_sqlite/src/wallet/db.rs) lines 745-792 — change the four `TABLE_ORCHARD_TREE_`* constants from `pub(super)` to `pub`. These are needed to create the ephemeral in-memory schema. Re-export them from a public path (e.g. via `wallet::db` or a new `pub mod tree_schema`).

## Governance block in lib.rs after cleanup

The `impl` block (lines 2319-2371) will shrink to contain only `get_orchard_notes_at_snapshot`. The comment block (lines 2313-2317) can be simplified to mention only the snapshot query.