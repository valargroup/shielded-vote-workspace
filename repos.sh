#!/usr/bin/env bash
# Manifest of child repos.
# Format: directory|clone_url|default_branch
REPOS=(
    "zcash_voting|git@github.com:valargroup/zcash_voting.git|main"
    "librustzcash|git@github.com:valargroup/librustzcash.git|shielded-voting-wallet-support"
    "vote-nullifier-pir|https://github.com/valargroup/vote-nullifier-pir.git|main"
    "vote-sdk|https://github.com/valargroup/vote-sdk|main"
    "voting-circuits|https://github.com/valargroup/voting-circuits.git|main"
    "zcash-swift-wallet-sdk|git@github.com:valargroup/zcash-swift-wallet-sdk.git|shielded-vote"
    "zodl-ios|git@github.com:valargroup/zodl-ios.git|shielded-vote"
    "shielded-vote-book|https://github.com/valargroup/shielded-vote-book|main"
)
