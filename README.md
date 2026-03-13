# shielded-voting-workspace

Development workspace for Zcash shielded governance voting. Coordinates cross-repo work across the full stack — from Rust protocol libraries through the Swift SDK to the iOS app.

## Repos

| Repo | What | Branch |
| --- | --- | --- |
| `librustzcash` | Wallet DB queries for governance (fork of zcash/librustzcash) | `valargroup/shielded-voting-support` |
| `librustvoting` | Voting protocol: hotkeys, ZKPs, encryption, PCZT construction | `main` |
| `voting-circuits` | Halo2 circuits for delegation proofs | `main` |
| `vote-nullifier-pir` | PIR-private nullifier exclusion | `main` |
| `vote-sdk` | Voting SDK | `main` |
| `vote-shielded-vote-generator-ui` | Vote generator UI | `main` |
| `zcash-swift-wallet-sdk` | Swift SDK with voting FFI (fork of zcash/zcash-swift-wallet-sdk) | `valargroup/governance-tree-state` |
| `zodl-ios` | iOS wallet app (fork of zodl-inc/zodl-ios) | `greg/adam/voting-store-bg` |
| `zebra` | Zcash node | `main` |

Repos are standalone clones in gitignored directories — each has its own git history and remotes.

## Setup

```
git clone <this-repo> shielded-voting-workspace
cd shielded-voting-workspace
mise install              # install toolchain (rust)
mise run git:sync         # clone all repos
mise run wire:local       # switch deps to local sibling paths
```

## Tasks

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
```

Patches live in `.wiring/` and are applied/reversed with `git apply`. The wired files use `skip-worktree` so the path changes don't pollute `git status`. `git:push` refuses to push while wired local.

## Architecture

```
zodl-ios (Swift/TCA)
  └─ zcash-swift-wallet-sdk (SPM)
       ├─ VotingRustBackend.swift (wraps C FFI)
       └─ libzcashlc.a (Rust staticlib)
            ├─ librustzcash  ← wallet DB queries
            └─ librustvoting ← voting protocol, ZKPs, encryption
                 └─ voting-circuits ← Halo2 proof circuits
```

See [UPSTREAM-SUMMARY.md](UPSTREAM-SUMMARY.md) for detailed per-repo change descriptions.
