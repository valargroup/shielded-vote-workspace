# Shielded Voting — Changes vs Upstream

Shielded governance voting for Zodl iOS. ZEC holders vote on governance proposals using zero-knowledge proofs that prove eligibility (note ownership at a snapshot height) without revealing identity or balance.

Four repos, layered bottom-up. One new library, three PRs against existing repos.

## Specification

Six draft ZIPs define the protocol:

| ZIP PR                                           | Title                                                                         |
| ------------------------------------------------ | ----------------------------------------------------------------------------- |
| [#1200](https://github.com/zcash/zips/pull/1200) | Shielded Voting Protocol (core — delegation, voting, share submission, tally) |
| [#1199](https://github.com/zcash/zips/pull/1199) | Orchard Proof-of-Balance                                                      |
| [#1198](https://github.com/zcash/zips/pull/1198) | Private Information Retrieval for Nullifier Exclusion Proofs                  |
| [#1201](https://github.com/zcash/zips/pull/1201) | Election Authority Key Ceremony                                               |
| [#1203](https://github.com/zcash/zips/pull/1203) | Shielded Coinholder Voting (setup)                                            |
| [#1218](https://github.com/zcash/zips/pull/1218) | Submission Server (temporal mixing)                                           |

## Architecture

```
zodl-ios (Swift/TCA)
  └─ zcash-swift-wallet-sdk (SPM)
       ├─ VotingRustBackend.swift (wraps C FFI)
       └─ libzcashlc.a (Rust staticlib)
            ├─ librustzcash  ← wallet DB queries
            └─ zcash_voting ← voting DB, ZKP proofs, encryption
```

zcash_voting never touches the wallet DB. The SDK FFI queries notes/witnesses via librustzcash and passes them to zcash_voting as arguments. This is the key separation of concerns — librustzcash owns the wallet domain, zcash_voting owns the voting domain, and the SDK wires them together.

---

## 1. librustzcash — [zcash/librustzcash#2212](https://github.com/zcash/librustzcash/pull/2212)

**Branch:** `shielded-voting-wallet-support` → `maint/zcash_client_sqlite-0.19.x`
**Diff:** 7 files, +280

Minimal surface area addition — two read-only PCZT getters and two governance-specific `WalletDb` methods (inherent, not on wallet traits):

- **`get_orchard_notes_at_snapshot()`** — backward-looking note query at a historical snapshot height
- **`generate_orchard_witnesses_at_frontier()`** — generates Merkle witnesses anchored at a historical frontier using an ephemeral in-memory DB (wallet DB is read-only)
- **PCZT getters** — `spend_auth_sig` (read back HW wallet signature for ZK proof), `shielded_sighash` (backport from main)

No new traits, no modifications to existing APIs.

---

## 2. zcash_voting — [valargroup/zcash_voting](https://github.com/valargroup/zcash_voting)

**New repo**, no upstream counterpart. Three workspace crates: core library, vote commitment tree, tree sync client.

Voting protocol implementation: hotkey derivation, governance PCZT construction, Halo2 ZKP proofs (delegation + vote), ElGamal vote encryption, PIR nullifier exclusion, vote commitment tree sync, SQLite round-state persistence.

**Key design decision:** no dependency on `zcash_client_sqlite` or `zcash_client_backend`. All wallet data arrives as function arguments — any wallet implementation can use it.

Dependencies: [voting-circuits](https://github.com/valargroup/voting-circuits) (orchard fork with governance ZKP gadgets), librustzcash crates for PCZT/key types.

---

## 3. zcash-swift-wallet-sdk — [zcash/zcash-swift-wallet-sdk#1657](https://github.com/zcash/zcash-swift-wallet-sdk/pull/1657)

**Branch:** `shielded-vote` → `main`
**Diff:** 12 files, +6,064/−524

The glue layer. 52 `extern "C"` FFI functions in `rust/src/voting.rs` + Swift wrappers (`VotingRustBackend.swift`, `VotingTypes.swift`).

Four FFI functions do wallet↔voting plumbing (open `WalletDb`, query notes/witnesses via librustzcash, convert to zcash_voting types). The remaining ~48 are thin pass-throughs to zcash_voting. Complex types cross the boundary via JSON serde; encrypted share secrets are stripped at the FFI boundary.

One new SDK API: `getTreeState(height:)` on `Synchronizer` for commitment tree witness generation.

---

## 4. zodl-ios — [zodl-inc/zodl-ios#1659](https://github.com/zodl-inc/zodl-ios/pull/1659)

**Branch:** `shielded-vote` → `main`
**Diff:** 63 files, +8,843/−194

Pure application layer — no direct FFI or wallet DB access. Five new SPM modules (`Voting`, `VotingModels`, `VotingAPIClient`, `VotingCryptoClient`, `VotingStorageClient`) plus `BackgroundTaskClient` for keeping the app alive during ZKP generation.

Core is `VotingStore`, a ~2,400-line TCA reducer managing the full lifecycle: delegation (PCZT → ZKP → on-chain TX), voting (commitment tree sync → vote commitment → encrypted share distribution), multi-bundle support, Keystone hardware wallet signing, and crash recovery with all intermediate state persisted to SQLite.

Server communication uses 3-tier service discovery, per-server circuit breaker health tracking, and client-side `submit_at` timestamp sampling for share distribution privacy.

Tests: ~715 lines covering delegation flow, Keystone pipeline, 6 crash recovery scenarios, and TX event parsing.

---

## Back-end protocol implementation

| Repo                                                                                             | Purpose                                                                                      |
| ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| [vote-sdk](https://github.com/valargroup/vote-sdk)                                               | Cosmos SDK application chain — delegation TX processing, vote commitment verification, tally |
| [voting-circuits](https://github.com/valargroup/voting-circuits)                                 | Halo2 circuits for delegation and vote proofs (orchard fork)                                 |
| [vote-nullifier-pir](https://github.com/valargroup/vote-nullifier-pir)                           | PIR server for nullifier non-membership proofs                                               |

## Merge order

1. **librustzcash** — independent, no voting deps
2. **zcash_voting** — independent repo, cargo patches should align with merged librustzcash
3. **zcash-swift-wallet-sdk** — depends on 1 + 2
4. **zodl-ios** — depends on 3
