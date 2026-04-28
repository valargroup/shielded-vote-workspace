# Vote SDK Primary Storage Findings

Date: 2026-04-28

## Host And Data Directory

The vote-sdk primary was checked over SSH at `165.245.219.62`.

The active node home on this host is:

```text
/root/.svoted
```

The application is not currently using the production-guide path `/opt/shielded-vote/.svoted` on this machine.

## Disk Usage

Total data directory size:

```text
/root/.svoted/data: 306M (320,524,288 bytes)
```

Top-level breakdown:

```text
application.db              130.5M   42.7%
cs.wal                       97.0M   31.7%
blockstore.db                52.1M   17.1%
tx_index.db                  14.6M    4.8%
state.db                     11.4M    3.7%
snapshots                    20.0K
evidence.db                  16.0K
priv_validator_state.json     4.0K
```

Only `application.db` is Cosmos SDK application state. The other directories are CometBFT/Tendermint block, consensus, state, evidence, and tx-index data.

## App State Attribution

The node is using `db_backend = "goleveldb"` and CometBFT `indexer = "kv"`.

`application.db` was copied locally and scanned by Cosmos SDK store prefix. Logical key/value bytes do not equal LevelDB disk bytes exactly, but they identify the app-state sources.

```text
staking          107.9M   46.1%
distribution      82.2M   35.1%
slashing          26.5M   11.3%
vote               1.4M    0.6%
consensus          1.3M    0.6%
bank               1.2M    0.5%
acc                1.2M    0.5%
root metadata     12.6M
```

The custom `vote` module is not the source of the growth. It is about `0.6%` of logical app DB content.

## Per-Block Growth

At the time of inspection, the node was around height `35,000`. Recent app DB growth came from SDK module writes on every block, even when blocks have no user transactions.

Recent per-block logical writes:

```text
staking          ~3.1K/block
distribution    ~2.4K/block
slashing         ~791B/block
vote             ~187B/block
consensus         ~40B/block
bank              ~35B/block
acc               ~34B/block
```

Recent leaf keys written per block:

```text
staking:
  0x50 HistoricalInfo
  0x61 ValidatorUpdates

distribution:
  0x00 FeePool
  0x01 PreviousProposer
  0x02 ValidatorOutstandingRewards
  0x06 ValidatorCurrentRewards
  0x07 ValidatorAccumulatedCommission

slashing:
  0x01 ValidatorSigningInfo
```

## Why Empty Blocks Grow App State

Empty blocks still execute Cosmos SDK BeginBlock/EndBlock logic and commit a new IAVL version.

Main sources:

- `staking` stores historical validator/header info every block. Current params show `historical_entries = 10000`.
- `staking` also writes validator update metadata every block.
- `distribution` updates proposer and reward accounting every block, even with zero fees.
- `slashing` updates validator signing/liveness info every block.
- root multistore metadata writes one `CommitInfo` per height.
- IAVL is versioned, so touched keys create new tree nodes instead of mutating existing nodes in place.

Pruning is currently:

```text
pruning = "default"
pruning-keep-recent = "0"
pruning-interval = "0"
```

The `svoted prune --help` output says `default` keeps the last `362880` app states. At only around `35,000` blocks, essentially no historical app versions have aged out yet.

## Possible Levers

- Reduce `staking.params.historical_entries` if the chain does not need 10,000 historical validator sets.
- Use more aggressive app pruning if historical state queries are not required.
- Disable or reduce empty block production if the deployment can tolerate that behavior.
- Consider whether standard `distribution` and `slashing` behavior is needed unchanged for this chain.
- Disable CometBFT tx indexing if API/query needs allow it; this affects `tx_index.db`, not `application.db`.
