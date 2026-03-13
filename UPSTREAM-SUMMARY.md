# Shielded Voting — Changes vs Upstream

Shielded governance voting for Zodl iOS. Four repos modified, layered bottom-up.

## Architecture

```
zodl-ios (Swift/TCA)
  └─ zcash-swift-wallet-sdk (SPM)
       ├─ VotingRustBackend.swift (wraps C FFI)
       └─ libzcashlc.a (Rust staticlib)
            ├─ librustzcash  ← wallet DB queries
            └─ librustvoting ← voting DB, ZKP proofs, encryption
```

librustvoting never touches the wallet DB. The SDK FFI queries notes/witnesses via librustzcash and passes them to librustvoting as arguments (`&[NoteInfo]`, `&[WitnessData]`).

---

## 1. librustzcash

**Repo:** [valargroup/librustzcash](https://github.com/valargroup/librustzcash) (fork of [zcash/librustzcash](https://github.com/zcash/librustzcash))
**PR:** [#4](https://github.com/valargroup/librustzcash/pull/4)
**Branch:** `valargroup/pczt-governance-extensions-0.11`
**Base:** `maint/zcash_client_sqlite-0.19.x` — **zero upstream drift**
**Diff:** 5 files, +271/−4

### Commit 1: PCZT visibility (2 files, +6)

Two small visibility changes so governance code can read signing results from PCZTs:

```diff
# pczt/src/orchard.rs — expose spend_auth_sig getter
+ #[getset(get = "pub")]
  pub(crate) spend_auth_sig: Option<[u8; 64]>,

# pczt/src/roles/signer/mod.rs — expose sighash (already on upstream main)
+ pub fn shielded_sighash(&self) -> [u8; 32] {
+     self.shielded_sighash
+ }
```

Both are read-only getters. `spend_auth_sig` is needed to extract the hardware wallet's signature after signing, so it can be threaded into the ZK delegation proof. `shielded_sighash` is already public on upstream `main` — this cherry-picks it to the 0.19.x branch.

No `set_orchard()`, no public `serialize_from()`. Governance PCZT construction uses the existing `Creator::build_from_parts` (added upstream in `318254cc5`), which accepts an `orchard::pczt::Bundle` directly as part of `PcztParts` — same code path the wallet transaction builder uses. See [librustvoting#1](https://github.com/valargroup/librustvoting/pull/1) for the consuming change.

### Commit 2: Governance wallet methods (3 files, +249)

Two new inherent methods on `WalletDb` (not on `WalletRead` trait — these are governance-specific, not general wallet API).

**`zcash_client_sqlite/src/wallet/orchard.rs`** — `get_orchard_notes_at_snapshot()`

Returns `Vec<ReceivedNote<ReceivedNoteId, orchard::Note>>` for notes mined at or before snapshot height and unspent as of that height. Backward-looking query (unlike `select_spendable_notes` which is forward-looking via tx expiry). Single SQL query against `orchard_received_notes` with a subquery excluding notes spent before snapshot.

**`zcash_client_sqlite/src/wallet/commitment_tree.rs`** — `generate_orchard_witnesses_at_frontier()`

Generates `Vec<MerklePath>` for given note positions, anchored at a historical frontier. The wallet's live tree may have advanced past the snapshot, so this:

1. Creates an in-memory SQLite DB
2. Copies the wallet's `orchard_tree_*` tables (read-only ATTACH + INSERT...SELECT)
3. Inserts the frontier (from lightwalletd's `TreeState`) as a checkpoint
4. Builds a `ShardTree` and generates witnesses via `witness_at_checkpoint_id`

The wallet DB is never modified.

**`zcash_client_sqlite/src/lib.rs`** — delegating methods on `WalletDb`, both behind `#[cfg(feature = "orchard")]`.

Also makes `SqliteShardStore::from_connection` pub (was `pub(crate)`) — needed by the witness generation code.

---

## 2. librustvoting (new repo, not upstream)

**Repo:** [valargroup/librustvoting](https://github.com/valargroup/librustvoting)

**No upstream counterpart** — this is a new Valar repo.
Voting protocol library: hotkey derivation, governance PCZT construction, Halo2 ZKP proof generation, ElGamal vote encryption, PIR-private nullifier exclusion, vote commitment tree sync.

Key design decision: librustvoting has **no dependency on `zcash_client_sqlite`** or `zcash_client_backend`. All wallet data arrives as function arguments. This means it can be used by any wallet implementation, not just the SQLite one.

### PCZT construction (`build_governance_pczt` in `action.rs`)

Governance PCZT construction uses `Creator::build_from_parts(PcztParts { ... })` — the same entry point the wallet transaction builder uses. The orchard bundle (built via `orchard::Builder::build_for_pczt()`) is passed directly as `PcztParts::orchard`, so `Creator` handles serialization internally. This keeps `serialize_from` as `pub(crate)` and avoids any raw setters on `Pczt`.

The full sequence:

1. `orchard::Builder` constructs the governance action (1 real spend + 1 real output, padded to 2 actions)
2. `Builder::build_for_pczt()` returns an `orchard::pczt::Bundle`
3. Updater sets ZIP-32 derivation metadata for Keystone
4. `Creator::build_from_parts(PcztParts { orchard: Some(bundle), .. })` produces the PCZT with correct tx version and network metadata
5. IO Finalizer computes binding signature key and sighash
6. Serialized PCZT goes to Keystone for signing

---

## 3. zcash-swift-wallet-sdk

**Repo:** [valargroup/zcash-swift-wallet-sdk](https://github.com/valargroup/zcash-swift-wallet-sdk) (fork of [zcash/zcash-swift-wallet-sdk](https://github.com/zcash/zcash-swift-wallet-sdk))
**PR:** [#2](https://github.com/valargroup/zcash-swift-wallet-sdk/pull/2)
**Branch:** `valargroup/governance-tree-state`
**Base:** `main` — **zero upstream drift**
**Diff:** 11 files, +5,521/−455 (most of −455 is Cargo.lock churn)

### New files

| File                                  | Lines | Purpose                                                                                 |
| ------------------------------------- | ----- | --------------------------------------------------------------------------------------- |
| `rust/src/voting.rs`                  | 2,314 | Hand-rolled C FFI: 43 `extern "C"` functions covering all voting operations             |
| `Sources/.../VotingRustBackend.swift` | 1,138 | Swift wrapper: opaque `VotingDatabaseHandle`, JSON serde across FFI, progress callbacks |
| `Sources/.../VotingTypes.swift`       | 408   | Codable Swift types mirroring Rust serde types                                          |
| `Scripts/prepare-fork-release.sh`     | 157   | Fork-only: builds iOS xcframework and uploads to GitHub Releases                        |

### Modified files

| File                           | Change                                                                                                                   |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| `Synchronizer.swift`           | +4: `getTreeState(height:)` protocol method                                                                              |
| `SDKSynchronizer.swift`        | +8: implementation (lightwalletd gRPC call)                                                                              |
| `rust/src/lib.rs`              | +1: `mod voting;`                                                                                                        |
| `Cargo.toml`                   | +25: `librustvoting`, `voting-circuits`, `incrementalmerkletree`, `serde`/`serde_json` deps, `[patch.crates-io]` section |
| `Package.swift`                | points binary target at valargroup fork release                                                                          |
| `AutoMockable.generated.swift` | +24: generated mock for `getTreeState`                                                                                   |

### `[patch.crates-io]` in Cargo.toml

Aligns dependency versions across the build — librustvoting depends on orchard 0.11 via voting-circuits (a fork with governance circuit gadgets), and on pczt/zcash_keys from the librustzcash governance branch. The patches ensure Cargo resolves all crates to the same source.

### FFI architecture (`rust/src/voting.rs`)

Follows the same patterns as the existing `lib.rs`/`ffi.rs`:

- Error handling: `catch_panic()` + `unwrap_exc_or_null()`
- Opaque pointers: `Box::into_raw` / `Box::from_raw`
- Complex types: JSON serialization across FFI (`serde_json`)
- Simple types: `#[repr(C)]` structs (`FfiRoundState`, `FfiVotingHotkey`, etc.)

Four functions do wallet↔voting plumbing:

- `zcashlc_voting_get_wallet_notes` — opens `WalletDb`, resolves account, calls `get_orchard_notes_at_snapshot`, converts each `ReceivedNote` → `NoteInfo`
- `zcashlc_voting_generate_note_witnesses` — loads tree state bytes from voting DB, parses protobuf frontier, opens `WalletDb`, calls `generate_orchard_witnesses_at_frontier`, converts `MerklePath` → `WitnessData`
- `zcashlc_voting_build_and_prove_delegation` — takes `notes_json` (not `wallet_db_path`)
- `zcashlc_voting_extract_nc_root` — parses `TreeState` protobuf, returns `orchard_tree().root()`

The remaining ~39 functions are thin pass-throughs to librustvoting (round lifecycle, hotkey gen, PCZT construction, proof generation, vote encryption, tree sync).

---

## 4. zodl-ios

**Repo:** [valargroup/zodl-ios](https://github.com/valargroup/zodl-ios) (fork of [zodl-inc/zodl-ios](https://github.com/zodl-inc/zodl-ios))
**PR:** [#2](https://github.com/valargroup/zodl-ios/pull/2)
**Branch:** `valargroup/shielded-voting`
**Base:** `main` — **zero upstream drift**
**Diff:** 59 files, +7,607/−198

This is the application layer. zodl-ios is a pure consumer — no direct FFI calls or wallet DB access.

### New modules (in `modules/Sources/`)

| Module                | Files | Purpose                                                                                                         |
| --------------------- | ----- | --------------------------------------------------------------------------------------------------------------- |
| `VotingModels`        | 6     | Types: sessions, proposals, delegation data, vote commitments, crypto primitives                                |
| `VotingAPIClient`     | 4     | REST client with 3-tier service discovery (local JSON → Vercel CDN → fallback), circuit breaker health tracking |
| `VotingCryptoClient`  | 3     | Bridge to SDK's `VotingRustBackend` — converts between VotingModels types and SDK types                         |
| `VotingStorageClient` | 3     | Keychain storage for hotkey seeds                                                                               |
| `Voting` (feature)    | 12    | TCA reducer (`VotingStore`, 2055 lines) + 11 SwiftUI views                                                      |

### Modified files

| File                                                         | Change                                           |
| ------------------------------------------------------------ | ------------------------------------------------ |
| `modules/Package.swift`                                      | voting module targets + SDK fork dependency      |
| `HomeStore.swift`, `MoreSheet.swift`                         | navigation entry point                           |
| `RootStore.swift`, `RootView.swift`, `RootCoordinator.swift` | route handling                                   |
| `ScanStore.swift`, `ScanChecker.swift`                       | delegation QR code scanning (Keystone HW wallet) |
| `SDKSynchronizerInterface/Live/Test.swift`                   | `getTreeState` wrapper                           |
| `WalletStorage*.swift`                                       | hotkey seed persistence                          |

### Tests

- `VotingStoreTests.swift` — TCA reducer tests for delegation proof flow
- `ScanTests.swift` — delegation QR scanning

---

## Upstream sync status

All branches fetched from upstream on 2026-03-11.

| Repo                   | Base branch                        | Our commits | Upstream drift |
| ---------------------- | ---------------------------------- | ----------- | -------------- |
| librustzcash           | `maint/zcash_client_sqlite-0.19.x` | 2           | 0              |
| zcash-swift-wallet-sdk | `main`                             | 8           | 0              |
| zodl-ios               | `main`                             | 12          | 0              |

No rebasing needed — PRs apply cleanly against current upstream HEAD.

## Merge order

1. **librustzcash** — independent, no voting deps
2. **librustvoting** — independent repo, but cargo patches should align with merged librustzcash
3. **zcash-swift-wallet-sdk** — depends on 1 + 2
4. **zodl-ios** — depends on 3
