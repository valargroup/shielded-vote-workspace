#!/usr/bin/env bash
# Per-repo wired files and their lock/resolved counterparts.
# Each entry: REPO_DIR:FILE_PATH (relative to repo root)

WIRED=(
    "librustvoting:Cargo.toml"
    "zcash-swift-wallet-sdk:Cargo.toml"
    "zodl-ios:modules/Package.swift"
)

WIRED_LOCKS=(
    "librustvoting:Cargo.lock"
    "zcash-swift-wallet-sdk:Cargo.lock"
    "zodl-ios:modules/Package.resolved"
)
