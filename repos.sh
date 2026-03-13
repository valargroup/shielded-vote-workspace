#!/usr/bin/env bash
# Manifest of child repos.
# Format: directory|clone_url|default_branch
REPOS=(
    "librustvoting|git@github.com:valargroup/librustvoting.git|main"
    "librustzcash|git@github.com:valargroup/librustzcash.git|valargroup/shielded-voting-support"
    "vote-nullifier-pir|https://github.com/valargroup/vote-nullifier-pir.git|main"
    "vote-sdk|https://github.com/valargroup/vote-sdk|main"
    "vote-shielded-vote-generator-ui|https://github.com/valargroup/vote-shielded-vote-generator-ui.git|main"
    "voting-circuits|https://github.com/valargroup/voting-circuits.git|main"
    "zcash-swift-wallet-sdk|git@github.com:valargroup/zcash-swift-wallet-sdk.git|valargroup/governance-tree-state"
    "zebra|git@github.com:ZcashFoundation/zebra.git|main"
    "zodl-ios|git@github.com:valargroup/zodl-ios.git|greg/adam/voting-store-bg"
)
