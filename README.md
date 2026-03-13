# shielded-voting-workspace

Development workspace for Zcash shielded governance voting. Coordinates cross-repo work across the full stack — from Rust protocol libraries through the Swift SDK to the iOS app.

## Repos

| Repo                              | What                                                             | Branch                               |
| --------------------------------- | ---------------------------------------------------------------- | ------------------------------------ |
| `librustzcash`                    | Wallet DB queries for governance (fork of zcash/librustzcash)    | `valargroup/shielded-voting-support` |
| `librustvoting`                   | Voting protocol: hotkeys, ZKPs, encryption, PCZT construction    | `main`                               |
| `voting-circuits`                 | Halo2 circuits for delegation proofs                             | `main`                               |
| `vote-nullifier-pir`              | PIR-private nullifier exclusion                                  | `main`                               |
| `vote-sdk`                        | Voting chain daemon + helper server                              | `main`                               |
| `vote-shielded-vote-generator-ui` | Admin UI for round/proposal management                           | `main`                               |
| `zcash-swift-wallet-sdk`          | Swift SDK with voting FFI (fork of zcash/zcash-swift-wallet-sdk) | `valargroup/governance-tree-state`   |
| `zodl-ios`                        | iOS wallet app (fork of zodl-inc/zodl-ios)                       | `valargroup/shielded-voting`         |
| `zebra`                           | Zcash node                                                       | `main`                               |

Repos are standalone clones in gitignored directories — each has its own git history and remotes.

## Setup

```
git clone <this-repo> shielded-voting-workspace
cd shielded-voting-workspace
mise install              # install toolchain (rust, go, node)
mise run git:sync         # clone all repos
mise run wire:local       # switch deps to local sibling paths
```

## Running locally

```
mise run start            # full stack: nullifiers + chain + admin UI
mise run status           # dashboard of all services
mise run stop             # kill everything
```

`mise run start` handles the full sequence:

1. **Nullifier pipeline** — bootstrap data from remote (~7.4 GB one-time download), ingest to chain tip, export PIR tier files, start PIR server (port 3000)
2. **Chain** — build vote-sdk with FFI, init single-validator chain, start daemon, wait for readiness, register Pallas key
3. **iOS config** — writes `zodl-ios/secant/Resources/voting-config-local.json` pointing at localhost
4. **Admin UI** — starts Vite dev server (port 5173)

To start just the chain without nullifiers: `mise run start:chain`

### Ports

| Service    | Port  |
| ---------- | ----- |
| Chain API  | 1318  |
| Chain RPC  | 26657 |
| PIR server | 3000  |
| Admin UI   | 5173  |

### iOS app

After `mise run start`, open `zodl-ios/secant.xcworkspace` in Xcode and build the `secant-mainnet` scheme for iOS Simulator. The local voting config is created automatically by `start:chain`.

## Tasks

### Services

```
mise run start            # nullifiers + chain + admin UI
mise run start:chain      # chain only (+ iOS config)
mise run stop             # stop all services
mise run status           # service dashboard
```

### Git coordination

```
mise run git:sync         # clone missing repos, fetch existing
mise run git:status       # branch + dirty state across all repos
mise run git:branch NAME  # create a branch across all (or specified) repos
mise run git:push         # push repos with unpushed commits
mise run git:drift        # fetch origins, show ahead/behind
```

### Dependency wiring

The repos depend on each other (Cargo `[patch]` sections, SPM package refs). Wiring toggles these between remote git URLs (for CI/PRs) and local sibling paths (for development).

```
mise run wire:local       # apply local path patches
mise run wire:remote      # reverse patches, restore git URLs
mise run wire:status      # show current state
mise run wire:update      # regenerate patches after editing wired files
```

Patches live in `.wiring/` and are applied/reversed with `git apply --reverse`. The wired files use `skip-worktree` so the path changes don't pollute `git status`. `git:push` refuses to push while wired local.

## Architecture

```
zodl-ios (Swift/TCA)
  └─ zcash-swift-wallet-sdk (SPM)
       ├─ VotingRustBackend.swift (wraps C FFI)
       └─ libzcashlc.a (Rust staticlib)
            ├─ librustzcash     ← wallet DB queries
            ├─ librustvoting    ← voting protocol, ZKPs, encryption
            │    └─ voting-circuits ← Halo2 proof circuits
            └─ vote-nullifier-pir  ← PIR nullifier exclusion

vote-sdk (Go/Cosmos)         ← chain daemon + helper server
vote-shielded-vote-generator-ui  ← admin UI (Vite/React)
```

See [UPSTREAM-SUMMARY.md](UPSTREAM-SUMMARY.md) for detailed per-repo change descriptions.
