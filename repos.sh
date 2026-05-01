#!/usr/bin/env bash
# Workspace manifest. Single source of truth for:
#   - child-repo clone URLs (REPOS)
#   - named states — each state is a full branch + wiring patch set (STATES)
#   - per-state branches and wired files (BRANCHES_*, WIRED_*, WIRED_LOCKS_*)
#
# Active state lives in .wiring/current-state (defaults to STATES[0] if absent
# or if the file names a state that no longer exists).
# Switch with: mise run wire:state <name>
# Apply local overrides with: mise run wire:local

# ─── Child repos ─────────────────────────────────────────
# Format: dir|clone_url. Branch comes from the active state's BRANCHES_* array.
REPOS=(
    "zcash_voting|git@github.com:valargroup/zcash_voting.git"
    "librustzcash|https://github.com/zcash/librustzcash.git"
    "orchard|https://github.com/zcash/orchard.git"
    "vote-nullifier-pir|https://github.com/valargroup/vote-nullifier-pir.git"
    "vote-sdk|https://github.com/valargroup/vote-sdk"
    "voting-circuits|https://github.com/valargroup/voting-circuits.git"
    "zcash-android-wallet-sdk|git@github.com:valargroup/zcash-android-wallet-sdk.git"
    "zcash-swift-wallet-sdk|git@github.com:valargroup/zcash-swift-wallet-sdk.git"
    "zodl-android|git@github.com:valargroup/zodl-android.git"
    "zodl-ios|git@github.com:valargroup/zodl-ios.git"
    "shielded-vote-book|https://github.com/valargroup/shielded-vote-book"
    "token-holder-voting-config|https://github.com/valargroup/token-holder-voting-config.git"
    "vote-infrastructure|https://github.com/valargroup/vote-infrastructure.git"
    "zips|https://github.com/zcash/zips.git"
    "ypir|git@github.com:valargroup/ypir.git"
    "spiral-rs|git@github.com:valargroup/spiral-rs.git"
)

# ─── States ──────────────────────────────────────────────
# Ordered. First entry is the default when .wiring/current-state is missing
# or invalid.
STATES=("current")

# ─── current: orchard 0.13
BRANCHES_current=(
    "zcash_voting:main"
    "librustzcash:main"
    "orchard:main"
    "vote-nullifier-pir:main"
    "vote-sdk:main"
    "voting-circuits:main"
    "zcash-android-wallet-sdk:shielded-vote"
    "zcash-swift-wallet-sdk:shielded-vote-2.4.10"
    "zodl-android:shielded-vote"
    "zodl-ios:shielded-vote-3.4.0"
    "shielded-vote-book:main"
    "token-holder-voting-config:main"
    "vote-infrastructure:main"
    "zips:main"
    "ypir:valar/artifact"
    "spiral-rs:valar/avoid-avx512"
)
WIRED_current=(
    "zcash_voting:Cargo.toml"
    "voting-circuits:voting-circuits/Cargo.toml"
    "vote-sdk:circuits/Cargo.toml"
    "vote-sdk:e2e-tests/Cargo.toml"
    "zcash-swift-wallet-sdk:Cargo.toml"
    "zodl-ios:secant.xcodeproj/project.pbxproj"
    "vote-nullifier-pir:Cargo.toml"
)
WIRED_LOCKS_current=(
    "zcash_voting:Cargo.lock"
    "vote-sdk:circuits/Cargo.lock"
    "vote-sdk:e2e-tests/Cargo.lock"
    "voting-circuits:voting-circuits/Cargo.lock"
    "zcash-swift-wallet-sdk:Cargo.lock"
    "zodl-ios:secant.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    "vote-nullifier-pir:Cargo.lock"
)

# ─── Helpers ─────────────────────────────────────────────
# Tasks call `wiring_load_state <state>` to populate plain BRANCHES / WIRED /
# WIRED_LOCKS arrays from the state-specific ones. Bash 3.2 compatible.
wiring_state_key() {
    local s="$1"
    # Sanitize: replace anything that can't appear in a bash identifier.
    s="${s//[^a-zA-Z0-9]/_}"
    printf '%s' "$s"
}

wiring_repo_exists() {
    # Git worktrees use a .git file instead of a .git directory.
    local repo_dir="$1"
    [ -e "$repo_dir/.git" ] && git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1
}

wiring_load_state() {
    local state="$1"
    local key
    key="$(wiring_state_key "$state")"
    local base src
    for base in BRANCHES WIRED WIRED_LOCKS; do
        src="${base}_${key}"
        # Copy the state-specific array into a plain name, empty if unset.
        eval "${base}=(\"\${${src}[@]+\"\${${src}[@]}\"}\")"
    done
}

wiring_active_state() {
    # $1 = workspace root (defaults to $DIR if set)
    local root="${1:-${DIR:-.}}"
    local s
    if [ -f "$root/.wiring/current-state" ]; then
        s="$(tr -d '\n' <"$root/.wiring/current-state")"
        if wiring_state_exists "$s"; then
            printf '%s' "$s"
            return 0
        fi
    fi
    printf '%s' "${STATES[0]}"
}

wiring_state_exists() {
    local name="$1"
    local s
    for s in "${STATES[@]}"; do
        [ "$s" = "$name" ] && return 0
    done
    return 1
}

wiring_branch_for_repo() {
    # $1 = repo dir, expects BRANCHES already loaded via wiring_load_state
    local repo="$1" entry
    for entry in "${BRANCHES[@]+"${BRANCHES[@]}"}"; do
        if [ "${entry%%:*}" = "$repo" ]; then
            printf '%s' "${entry#*:}"
            return 0
        fi
    done
    return 1
}
