# shielded-voting-workspace

Development workspace for Zcash shielded governance voting. Coordinates cross-repo work across the full stack, from Rust protocol libraries through the Swift SDK, iOS app, chain services, config, docs, and infrastructure.

## Quick start

For the common Android staging flow, use one command:

```
mise run android:run-stage
```

This builds and installs the Android debug app against the local
`zcash-android-wallet-sdk` checkout, so the SDK FFI is compiled locally when
needed. Voting endpoints still come from the pinned staging static config, which
uses the remote stage chain and remote stage PIR server. No environment
variables are required.

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
| `zcash-android-wallet-sdk`     | Android SDK with voting backend                               | `main`                 |
| `zcash-swift-wallet-sdk`       | Swift SDK with voting FFI                                     | `main`                 |
| `zodl-android`                 | Android wallet app                                            | `main`                 |
| `zodl-ios`                     | iOS wallet app                                                | `main`                 |
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
mise install              # install toolchain (rust, go, node, caddy)
mise run git:sync         # clone all repos
mise run wire:state       # show active state and expected branches
mise run wire:local       # switch deps to local sibling paths
```

`mise run git:sync` clones missing repos on the active state's branch, fetches existing repos, and fast-forwards clean branches when safe.

## Running locally

```
mise run start            # local chain + chain-hosted admin UI + local app config
mise run status           # dashboard of all services
mise run stop             # kill everything
```

`mise run start` handles the full sequence:

1. **Admin UI build** — build the Vite app into `vote-sdk/ui/dist`
2. **Chain** — build vote-sdk with its committed dependencies, init a single-validator chain, start daemon with `--serve-ui`, wait for readiness, register the Pallas key
3. **Android local config** — generate static/dynamic voting config under `.wiring/generated/voting-config/` and serve it through a local Caddy HTTPS proxy on port 8443
4. **iOS local config** — generate the matching iOS static/dynamic config from the same signed local round registry

PIR is remote by default. `svoted` starts with `SVOTE_PIR_URL=https://prod.pir.valargroup.org`, and the generated Android/iOS dynamic config keeps the production PIR endpoints. Use `mise run start:nf` only for explicit local PIR experiments. Set `SVOTE_PIR_START_SYNC=1` before `mise run start:nf` only when you want to rebuild local nullifier/PIR data from lightwalletd.

To start individual services, use `mise run start:chain`, `mise run start:config`, or the optional `mise run start:nf`.

For localhost-only admin UI builds, `mise run start` injects the first `VM_PRIVKEYS` entry from `vote-sdk/.env` into the built UI and auto-connects it when the page is opened from localhost. This keeps local round publishing one-click without affecting remote/admin deployments.

### Ports

| Service            | Port  | Notes                     |
| ------------------ | ----- | ------------------------- |
| Chain API          | 1317  | local                     |
| Chain RPC          | 26657 | local                     |
| Admin UI           | 1317  | served by the chain       |
| Config HTTPS proxy | 8443  | local static/dynamic JSON |
| PIR server         | 3000  | optional local experiment |

### iOS app

```
mise run start:ios        # build Rust xcframework for simulator + device, then open Xcode
```

When wired local, this builds the Rust FFI as a local xcframework for simulator and device, sets up `LocalPackages/` so the SDK auto-detects it, and opens `zodl-ios/secant.xcodeproj`. When wired remote, SPM fetches the prebuilt xcframework.

The Swift SDK always prefers `LocalPackages/` when it exists. `mise run wire:remote` moves it to a per-state stash so remote wiring uses the release binary, and `mise run wire:local` restores that stash so local FFI rebuilds are fast.

The debug voting config generated for zodl-ios defaults to `localhost`, which is correct for the simulator. `mise run wire:ios-config` prints the HTTPS static config URL to paste into the app's voting config override settings. For a real device, regenerate it with `SVOTE_IOS_HOST=lan mise run wire:ios-config` before building, or set `SVOTE_IOS_HOST` to an explicit hostname/IP.

After Rust code changes, re-run `mise run start:ios` to rebuild the xcframework, then Cmd+R again in Xcode. Swift-only changes just need Cmd+R.

The iOS app fetches its voting service config from the [Cloudflare-managed config host](https://voting.valargroup.org/) at startup.

### Android app

```
mise run android:emu      # boot the named Android emulator outside Android Studio
mise run android:run      # build, install, and launch zcashmainnetFossDebug
mise run android:run-local # apply local SDK wiring, then run Android
mise run android:run-stage # local SDK build + remote stage chain/PIR config
```

For the standard local emulator flow:

```
mise run start
mise run wire:local
mise run android:run
```

`mise run android:run-local` is the one-command variant for the last two lines: it applies local SDK wiring and then runs `android:run`.

`mise run android:run-stage` is the staging variant: it uses the local Android
SDK included build, keeps the SDK's Rust voting dependencies on their remote
versions, and injects the pinned stage voting config after launch.

`mise run start` brings up the local chain, admin UI, and HTTPS voting-config proxy. `android:run` boots the emulator if needed, builds and installs the debug APK, regenerates local Android voting config by default, injects the `voting_config_url` debug override, installs the local Caddy CA on a rootable emulator, and launches the app.

After publishing a local voting round, or any time the chain has new round data that should be signed into app dynamic config, regenerate both configs:

```
mise run wire:android-config local
mise run wire:ios-config
```

Defaults:

- AVD: `Pixel_6_API_33_zodl`
- package: `co.electriccoin.zcash.foss.debug`
- Gradle task: `:app:assembleZcashmainnetFossDebug`
- voting config: `local`

`android:run` defaults to `SVOTE_ANDROID_CONFIG=local`: it generates local static/dynamic voting config, starts the Caddy-backed `start:config` HTTPS proxy, installs the debug app, and injects `voting_config_url` through the debug broadcast receiver. Emulator builds use Android's `10.0.2.2` host bridge, so the generated static config points at `https://config.10-0-2-2.sslip.io:8443/static-voting-config.json`; the dynamic config points vote-sdk at `http://10.0.2.2:1317` and keeps PIR on the remote production endpoints.

Caddy uses its local CA for emulator/LAN profiles. The debug Android app trusts user-installed CAs through `app/src/debug/res/xml/network_security_config.xml`; release builds are unaffected. The standard rootable emulator path installs the generated Caddy root CA automatically. For a physical or non-root device, use the manual installer:

```
SVOTE_ANDROID_CA_INSTALL_MODE=prompt mise run wire:android-config local
```

The task pushes the CA certificate and opens Android's certificate installer when `adb` allows it. Android still requires user approval. The certificate path is printed as a fallback.

When the local chain is already running, `wire:android-config local` also queries `http://localhost:1317/shielded-vote/v1/rounds` and merges signed v2 dynamic-config entries for any local rounds that already have an `ea_pk`. Re-run it after creating a local round and letting DKG populate `ea_pk`. It uses the development-only `valar-test` key from `token-holder-voting-config/test/valar-test.seed.b64`, which is trusted by the repo's static config. Set `SVOTE_ANDROID_SIGN_LOCAL_ROUNDS=0` to skip this, `SVOTE_CONFIG_CHAIN_QUERY_URL` to query a different chain URL, or `SVOTE_VOTING_CONFIG_BIN` to use a prebuilt `voting-config` binary.

Use `SVOTE_ANDROID_CONFIG=remote mise run android:run` to clear the override and use the bundled CDN config. For a physical device on the LAN, run with `SVOTE_ANDROID_HOST=lan`; the task derives your LAN IP and generates `*.sslip.io` hostnames for that address.

Dependency wiring is separate from endpoint wiring. `mise run wire:local` sets `zodl-android/gradle.properties` to use the sibling `zcash-android-wallet-sdk` checkout via `SDK_INCLUDED_BUILD_PATH=../zcash-android-wallet-sdk`; wires the Android and Swift SDKs to local `librustzcash` and local `zcash_voting`; and changes zodl-ios to use the sibling `zcash-swift-wallet-sdk` package. `mise run wire:remote` restores Maven/SPM/Cargo remote resolution.

The helper leaves `~/.android/advancedFeatures.ini` untouched and picks a renderer at launch time. On macOS arm64 it defaults to the software-safe path (`-gpu swiftshader_indirect -feature -Vulkan -feature -GLDirectMem`) to avoid Apple Silicon flicker; elsewhere it uses `-gpu auto`. To force a specific renderer for troubleshooting, set `ANDROID_EMULATOR_GPU_MODE` when invoking the task, for example `ANDROID_EMULATOR_GPU_MODE=auto mise run android:emu` or `ANDROID_EMULATOR_GPU_MODE=host mise run android:emu`.

## Tasks

### Services

```
mise run start            # local chain + chain-hosted admin UI + local app config
mise run start:chain      # build UI + init + start single-validator chain
mise run start:config     # local HTTPS voting config proxy
mise run start:nf         # optional local PIR server experiment
mise run start:ios        # build xcframework for simulator + device, then open Xcode
mise run android:emu      # boot the named Android emulator outside Android Studio
mise run android:run      # build, install, and launch zcashmainnetFossDebug
mise run android:run-local # apply local SDK wiring, then run Android
mise run android:run-stage # local SDK build + remote stage chain/PIR config
mise run stop             # stop all services
mise run stop:chain       # stop svoted (chain + admin UI)
mise run stop:config      # stop local HTTPS voting config proxy
mise run stop:nf          # stop only nf-server
mise run status           # service dashboard
mise run logs             # tail merged logs from svoted, nf-server, and config proxy
```

`start:nf` skips local nullifier sync/export by default. If `vote-nullifier-pir/pir-data/` already contains `pir_root.json` and `tier0.bin`/`tier1.bin`/`tier2.bin`, it starts against those files and disables startup CDN bootstrap. Set `SVOTE_PIR_START_SYNC=1` to rebuild local PIR data before serving, or set `SVOTE_PIR_VOTING_CONFIG_URL=...` to force the server's bootstrap discovery path.

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
mise run wire:android-config local   # generate/inject local Android voting config
mise run wire:android-config remote  # clear Android override and use bundled CDN config
mise run wire:ios-config             # generate iOS local voting config and print override URL
mise run wire:status      # show current state
mise run wire:update      # regenerate patches after editing wired files
```

Patches live in `.wiring/states/<state>/` and are applied/reversed with `git apply`. Wired files use `skip-worktree` so local path overrides do not pollute child-repo `git status`. `git:push` refuses to push while wired local.

The `current` state wires:

- `zodl-android/gradle.properties`
- `zcash-android-wallet-sdk/backend-lib/Cargo.toml`
- `zcash-swift-wallet-sdk/Cargo.toml`
- `zodl-ios/secant.xcodeproj/project.pbxproj`

Local wiring intentionally does not patch `vote-sdk`, `vote-nullifier-pir`, `voting-circuits`, or the `zcash_voting` manifest. The local chain and `zcash_voting` use their checked-in remote dependency graph; only the mobile app to SDK path and the SDK to local `librustzcash`/`zcash_voting` path are overridden.

Run `mise run wire:status` before editing any wired manifest or lock file. After intentional edits while wired local, run `mise run wire:update` to regenerate the state patches.

## Architecture

```
zodl-ios
  └─ zcash-swift-wallet-sdk (local SPM package when wired local)
       └─ libzcashlc.a / xcframework
            ├─ librustzcash  ← local path patch
            └─ zcash_voting  ← local path patch, remote transitive deps

zodl-android
  └─ zcash-android-wallet-sdk (local included build when wired local)
       └─ backend-lib Rust/JNI
            ├─ librustzcash  ← local path patch
            └─ zcash_voting  ← local path dependency, remote transitive deps

vote-sdk (Go/Cosmos)         ← local chain daemon + helper server + admin UI
PIR                          ← remote deployment by default
token-holder-voting-config   ← public config plus local generated overrides
shielded-vote-book           ← documentation
vote-infrastructure          ← deployment/infrastructure
```

See [UPSTREAM-SUMMARY.md](UPSTREAM-SUMMARY.md) for detailed per-repo change descriptions.
