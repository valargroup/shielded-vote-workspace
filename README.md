# shielded-voting-workspace

Development workspace for Zcash shielded governance voting. Coordinates cross-repo work across the full stack, from Rust protocol libraries through the Swift SDK, iOS app, chain services, config, docs, and infrastructure.

## Repos

`repos.sh` is the source of truth for child repos, clone URLs, workspace states, branches, and dependency wiring. Repos are standalone clones in gitignored directories; each has its own git history and remotes.

The default state is `current` unless `.wiring/current-state` selects another valid state.

| Repo                           | What                                                          | `current` branch       |
| ------------------------------ | ------------------------------------------------------------- | ---------------------- |
| `zcash_voting`                 | Voting protocol: hotkeys, ZKPs, encryption, PCZT construction | `main`                 |
| `librustzcash`                 | Wallet DB queries for governance                              | `main`                 |
| `orchard`                      | Orchard protocol dependency                                   | `main`                 |
| `vote-nullifier-pir`           | PIR-private nullifier exclusion                               | `main`                 |
| `vote-sdk`                     | Voting chain daemon, helper server, and admin UI              | `main`                 |
| `voting-circuits`              | Halo2 circuits for delegation proofs                          | `main`                 |
| `zcash-android-wallet-sdk`     | Android SDK with voting backend                               | `shielded-vote`       |
| `zcash-swift-wallet-sdk`       | Swift SDK with voting FFI                                     | `shielded-vote-2.4.10` |
| `zodl-android`                 | Android wallet app                                            | `shielded-vote`       |
| `zodl-ios`                     | iOS wallet app                                                | `shielded-vote-3.4.0`  |
| `shielded-vote-book`           | Project documentation                                         | `main`                 |
| `token-holder-voting-config`   | Public voting service configuration                           | `main`                 |
| `vote-infrastructure`          | Deployment and infrastructure configuration                   | `main`                 |
| `zips`                         | Zcash Improvement Proposals                                   | `main`                 |
| `ypir`                         | PIR backend dependency                                        | `valar/artifact`       |
| `spiral-rs`                    | PIR backend dependency                                        | `valar/avoid-avx512`   |

## Setup

```
git clone <this-repo> shielded-voting-workspace
cd shielded-voting-workspace
mise install              # install toolchain (rust, go, node)
mise run git:sync         # clone all repos
mise run wire:state       # show active state and expected branches
mise run wire:local       # switch deps to local sibling paths
```

`mise run git:sync` clones missing repos on the active state's branch, fetches existing repos, and fast-forwards clean branches when safe.

## Running locally

```
mise run start            # full stack: PIR server + chain-hosted admin UI
mise run status           # dashboard of all services
mise run stop             # kill everything
```

`mise run start` handles the full sequence:

1. **PIR server** — start `nf-server` (port 3000) and let it bootstrap tier files from the published CDN snapshot
2. **Admin UI build** — build the Vite app into `vote-sdk/ui/dist`
3. **Chain** — build vote-sdk with FFI, init single-validator chain, start daemon with `--serve-ui`, wait for readiness, register Pallas key
4. **iOS local config** — refresh `zodl-ios/secant/Resources/voting-config-local.json` for simulator/debug workflows

To start individual services, use `mise run start:nf` or `mise run start:chain`.
Set `SVOTE_PIR_START_SYNC=1` before `mise run start:nf` only when you want to rebuild local nullifier/PIR data from lightwalletd.

### Ports

| Service    | Port  |
| ---------- | ----- |
| Chain API  | 1317  |
| Chain RPC  | 26657 |
| PIR server | 3000  |
| Admin UI   | 1317  |

### iOS app

```
mise run start:ios        # build Rust xcframework for simulator + device, then open Xcode
```

When wired local, this builds the Rust FFI as a local xcframework for simulator and device, sets up `LocalPackages/` so the SDK auto-detects it, and opens `zodl-ios/secant.xcodeproj`. When wired remote, SPM fetches the prebuilt xcframework.

The debug voting config generated for zodl-ios defaults to `localhost`, which is correct for the simulator. For a real device, regenerate it with `SVOTE_IOS_HOST=lan mise run wire:ios-config` before building, or set `SVOTE_IOS_HOST` to an explicit hostname/IP.

After Rust code changes, re-run `mise run start:ios` to rebuild the xcframework, then Cmd+R again in Xcode. Swift-only changes just need Cmd+R.

The iOS app fetches its voting service config from the [Cloudflare-managed config host](https://voting.valargroup.org/) at startup.

### Android app

```
mise run android:emu      # boot the named Android emulator outside Android Studio
mise run android:run      # build, install, and launch zcashmainnetFossDebug
```

Defaults:

- AVD: `Pixel_6_API_33_zodl`
- package: `co.electriccoin.zcash.foss.debug`
- Gradle task: `:app:assembleZcashmainnetFossDebug`

The helper leaves `~/.android/advancedFeatures.ini` untouched and picks a renderer at launch time. On macOS arm64 it defaults to the software-safe path (`-gpu swiftshader_indirect -feature -Vulkan -feature -GLDirectMem`) to avoid Apple Silicon flicker; elsewhere it uses `-gpu auto`. To force a specific renderer for troubleshooting, set `ANDROID_EMULATOR_GPU_MODE` when invoking the task, for example `ANDROID_EMULATOR_GPU_MODE=auto mise run android:emu` or `ANDROID_EMULATOR_GPU_MODE=host mise run android:emu`.

## Tasks

### Services

```
mise run start            # PIR server + chain-hosted admin UI
mise run start:chain      # build UI + init + start single-validator chain
mise run start:nf         # start PIR server; CDN bootstrap by default
mise run start:ios        # build xcframework for simulator + device, then open Xcode
mise run android:emu      # boot the named Android emulator outside Android Studio
mise run android:run      # build, install, and launch zcashmainnetFossDebug
mise run stop             # stop all services
mise run stop:chain       # stop svoted (chain + admin UI)
mise run stop:nf          # stop only nf-server
mise run status           # service dashboard
mise run logs             # tail merged logs from svoted and nf-server
```

### Git coordination

```
mise run git:sync         # clone missing repos, fetch existing
mise run git:status       # branch + dirty state across all repos
mise run git:branch NAME  # create a branch across all (or specified) repos
mise run git:push         # push repos with unpushed commits
mise run git:drift        # fetch origins, show ahead/behind
```

Commits go to child repos, not this umbrella repo, unless the change is workspace coordination infrastructure such as `repos.sh`, `.mise/tasks/`, `.wiring/`, or this README.

### Dependency wiring

The repos depend on each other (Cargo `[patch]` sections, SPM package refs). Wiring toggles these between remote git URLs (for CI/PRs) and local sibling paths (for development).

```
mise run wire:state       # show active workspace state
mise run wire:state NAME  # switch repo branches to another state
mise run wire:local       # apply local path patches
mise run wire:remote      # reverse patches, restore git URLs
mise run wire:status      # show current state
mise run wire:update      # regenerate patches after editing wired files
```

Patches live in `.wiring/states/<state>/` and are applied/reversed with `git apply`. Wired files use `skip-worktree` so local path overrides do not pollute child-repo `git status`. `git:push` refuses to push while wired local.

The `current` state wires:

- `zcash_voting/Cargo.toml`
- `voting-circuits/voting-circuits/Cargo.toml`
- `vote-sdk/circuits/Cargo.toml`
- `vote-sdk/e2e-tests/Cargo.toml`
- `zcash-swift-wallet-sdk/Cargo.toml`
- `zodl-ios/secant.xcodeproj/project.pbxproj`
- `vote-nullifier-pir/Cargo.toml`

Run `mise run wire:status` before editing any wired manifest or lock file. After intentional edits while wired local, run `mise run wire:update` to regenerate the state patches.

## Architecture

```
zodl-ios (Swift/TCA)
  └─ zcash-swift-wallet-sdk (SPM)
       ├─ VotingRustBackend.swift (wraps C FFI)
       └─ libzcashlc.a (Rust staticlib)
            ├─ librustzcash     ← wallet DB queries
            ├─ zcash_voting     ← voting protocol, ZKPs, encryption
            │    └─ voting-circuits ← Halo2 proof circuits
            └─ vote-nullifier-pir  ← PIR nullifier exclusion

vote-sdk (Go/Cosmos)         ← chain daemon + helper server + admin UI
token-holder-voting-config   ← public config consumed by iOS app
shielded-vote-book           ← documentation
vote-infrastructure          ← deployment/infrastructure
```

See [UPSTREAM-SUMMARY.md](UPSTREAM-SUMMARY.md) for detailed per-repo change descriptions.
