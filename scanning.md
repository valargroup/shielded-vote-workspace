# Membership Proofs at Historical Heights

## General Mechanism

At voting snapshot height, we need to construct the witnesses.

The anchor (tree root) is fixed by the voting protocol, and witnesses are only valid relative to a specific root.

To construct the witnesses at a historical height, we need a sibling path from the leaf to the root at the voting snapshot height.

Notes may be in different shards, the tree advanced past [PRUNING_DEPTH of 100](https://github.com/valargroup/librustzcash/blob/14c9cbc38fe6fab9b1ce8b4f10813de4ae54ae8e/zcash_client_sqlite/src/lib.rs#L167-L170), having pruned the tree elements necessary for witness construction.

## How It Works

How it works:
To construct witnesses at a historical height, we need:
1. Authentication path within each note's shard.
  * The scanner marks the wallet's notes as MARKED. This prevents
  them and their siblings within a shard from being pruned.
2. Cap - the upper tree above the shard level
3. Frontier - the right edge at the historical height.
  * It lets ShardTree know exactly where the tree ended at the historical height.

We copy the wallet's Orchard shard data into an ephemeral in-memory database,
inserts the provided frontier from lightwalletd at that height as a checkpoint, and
generate a witness for each of the given note positions.

It is assumed that the caller provides the valid frontier at the given height.

The reason for this reconstruction is due to the wallet automatically pruning
the tree after PRUNING_DEPTH of checkpoints/heights. The availability of
all 3 components from above allows us to reconstruct the sufficient tree structure for generating witnesses.

Below, we analyze the risks.

## Risk of Note Spend After Voting Snapshot Leading To Shard Tree Removal

Let height X be the voting snapshot height.

Assume the following sequence:

1. Height ≤ X: Note received -> Added to the local commitment tree
2. Height X + 50: Note spent -> Marked for pruning from the local commitment tree
3. Height X + 100: Wallet starts making a delegation to vote at height X.
   * It needs to construct a witness at height X for the note that was later spent.

Assumed Problem: What if the note's witness was removed from the tree?

What was assumed previously?

During step 2, the note is set for deletion and has a chance of pruning.

Facts to disprove that

- [MARKED](https://github.com/zcash/incrementalmerkletree/blob/edf24f2b2e727776e290f292d831d4ac61c3e1bd/incrementalmerkletree/src/lib.rs#L100-L102) means that "retention will be retained in the tree during pruning. Retention may only be explicitly removed."
- The only way to "explicitly remove" us by calling [remove_mark](https://github.com/zcash/incrementalmerkletree/blob/edf24f2b2e727776e290f292d831d4ac61c3e1bd/shardtree/src/lib.rs#L1395-L1405)
  * Try searching for "remove_mark" [here](https://github.dev/valargroup/Shielded-Vote)
- Additionally, marking Orchard note as spent DOES NOT unmark the note in the incremental tree. See [here](https://github.com/valargroup/librustzcash/blob/4b690e6ca8c809693b4119c17500ac724494cd87/zcash_client_sqlite/src/wallet/orchard.rs#L481-L505) 
- Checkpoint pruning logic only prunes nodes that have been explicitly [tagged by remove_mark](https://github.com/zcash/incrementalmerkletree/blob/edf24f2b2e727776e290f292d831d4ac61c3e1bd/shardtree/src/lib.rs#L1431-L1434)

Therefore, we can be confident that the MARKED notes stay in the tree forever.
